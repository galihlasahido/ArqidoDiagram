import AppKit
import SwiftUI
import DiagramModel
import DiagramPersistence

/// `NSDocument`, not SwiftUI `DocumentGroup`/`FileDocument` — this gives
/// direct hooks for in-place autosave, atomic package saves, async
/// background writes, and the built-in crash-recovery relaunch prompt, all
/// called out by name in the governing spec. SwiftUI still owns the UI: see
/// `DiagramDocumentWindowController`, which hosts `ContentView` via
/// `NSHostingView` inside a plain `NSWindow`.
///
/// Conforms to `ObservableObject` (harmless for an `NSObject` subclass) so
/// SwiftUI can `@ObservedObject` the coarse, document-level state (title,
/// page list) it actually needs — this is distinct from the *live* editing
/// `SceneStore` added in a later build-order step, which is deliberately
/// never `@Published`.
@objc(DiagramDocument)
final class DiagramDocument: NSDocument, ObservableObject {
    @Published private(set) var model: DiagramDocumentModel

    /// Set once the user chooses "Set Document Password…" or successfully
    /// unlocks an already-encrypted document — in memory only, never
    /// written into `model`/persisted directly (only `PackageWriter`'s
    /// derived key ever touches disk, via `encryption.json`'s salt).
    private var password: String?
    var isEncrypted: Bool { password != nil }

    override init() {
        model = .blank(at: Date())
        super.init()
    }

    /// "New from Template" (see `TemplatePickerWindowController`) — the
    /// template's page replaces the blank starter page's *content* while
    /// keeping its id/order, so the document is otherwise a completely
    /// ordinary one-page document, not a special template-backed mode.
    /// Starts unmodified (no `updateChangeCount`), same as a blank new
    /// document: this is the document's starting state, not a user edit.
    convenience init(template: DiagramTemplate) {
        self.init()
        guard let pageID = model.pageOrder.first else { return }
        var page = template.makePage()
        page.id = pageID
        page.order = 0
        model.pages = [pageID: page]
        model.title = template.name
    }

    /// Writes a page's live content (nodes/edges/groups/z-order) back into
    /// `model` — the canvas's `SceneStore` is the source of truth while
    /// editing, but `model` is what `fileWrapper(ofType:)` actually
    /// persists, so every committed canvas edit needs to land here (see
    /// `DiagramCanvasView.onSceneChanged`).
    func updatePage(_ page: DiagramPage) {
        model.pages[page.id] = page
        model.modifiedAt = Date()
    }

    // MARK: - Page management
    //
    // Page add/rename/delete/duplicate/reorder are document-level structural
    // changes, not a mutation of the currently active page's live scene —
    // they go through `undoManager` directly here rather than through
    // DiagramCommands/SceneStore (which is scoped to one page at a time).

    @discardableResult
    func addPage(named name: String? = nil) -> PageID {
        let page = DiagramPage(name: name ?? "Page \(model.pageOrder.count + 1)", order: model.pageOrder.count)
        insertPage(page, at: model.pageOrder.count, actionName: "Add Page")
        return page.id
    }

    func duplicatePage(id: PageID) {
        guard let original = model.pages[id] else { return }
        var copy = original
        copy.id = PageID()
        copy.name = original.name + " Copy"
        let index = (model.pageOrder.firstIndex(of: id) ?? model.pageOrder.count - 1) + 1
        insertPage(copy, at: index, actionName: "Duplicate Page")
    }

    func removePage(id: PageID) {
        guard let page = model.pages[id] else { return }
        let index = model.pageOrder.firstIndex(of: id) ?? model.pageOrder.count
        undoManager?.registerUndo(withTarget: self) { doc in
            doc.insertPage(page, at: index, actionName: "Delete Page")
        }
        undoManager?.setActionName("Delete Page")
        model.pages.removeValue(forKey: id)
        model.pageOrder.removeAll { $0 == id }
        model.modifiedAt = Date()
    }

    func renamePage(id: PageID, to newName: String) {
        guard var page = model.pages[id], !newName.isEmpty, newName != page.name else { return }
        let oldName = page.name
        undoManager?.registerUndo(withTarget: self) { doc in
            doc.renamePage(id: id, to: oldName)
        }
        undoManager?.setActionName("Rename Page")
        page.name = newName
        model.pages[id] = page
        model.modifiedAt = Date()
    }

    private func insertPage(_ page: DiagramPage, at index: Int, actionName: String) {
        undoManager?.registerUndo(withTarget: self) { doc in
            doc.removePage(id: page.id)
        }
        undoManager?.setActionName(actionName)
        model.pages[page.id] = page
        model.pageOrder.insert(page.id, at: min(index, model.pageOrder.count))
        model.modifiedAt = Date()
    }

    override class var autosavesInPlace: Bool { true }

    override func makeWindowControllers() {
        addWindowController(DiagramDocumentWindowController(document: self))
    }

    override func fileWrapper(ofType typeName: String) throws -> FileWrapper {
        model.modifiedAt = Date()
        // Built entirely in memory before returning — a thrown error here
        // never touches the previously-saved on-disk package, and
        // NSDocument's standard package-write path (temp file + atomic
        // rename) handles on-disk atomicity on top of that.
        return try PackageWriter.fileWrapper(for: model, password: password)
    }

    /// Runs on the main thread (the default for `canConcurrentlyReadDocuments
    /// == false`, which this class doesn't override), so a synchronous
    /// modal password prompt here is safe — the same reasoning
    /// `DiagramCanvasView.saveSelectionAsComponent`'s `NSAlert` relies on.
    override func read(from fileWrapper: FileWrapper, ofType typeName: String) throws {
        let peek = try PackageReader.peekManifest(from: fileWrapper)
        guard peek.isEncrypted else {
            model = try PackageReader.documentModel(from: fileWrapper)
            return
        }

        if let savedPassword = KeychainPasswordStore.load(for: peek.documentID),
           let decoded = try? PackageReader.documentModel(from: fileWrapper, password: savedPassword) {
            model = decoded
            password = savedPassword
            return
        }

        while true {
            guard let entered = promptForExistingPassword(documentID: peek.documentID) else {
                throw PackageReadError.encryptionPasswordRequired
            }
            do {
                model = try PackageReader.documentModel(from: fileWrapper, password: entered)
                password = entered
                return
            } catch PackageReadError.incorrectPassword {
                continue
            }
        }
    }

    override func canAsynchronouslyWrite(
        to url: URL,
        ofType typeName: String,
        for saveOperation: NSDocument.SaveOperationType
    ) -> Bool {
        true
    }

    // MARK: - Document encryption
    //
    // Spec §SECURITY: "Optional encrypted documents" + "macOS Keychain".
    // AES-GCM content encryption lives in DiagramPersistence
    // (DocumentEncryption/PackageWriter/PackageReader) — this is only the
    // password-prompt/Keychain-glue layer, kept at the app-target edge
    // since NSAlert has no place in a Foundation-only package module.

    @objc func setDocumentPassword(_ sender: Any?) {
        guard let entered = promptForNewPassword(documentID: model.documentID) else { return }
        password = entered
        updateChangeCount(.changeDone)
    }

    @objc func removeDocumentPassword(_ sender: Any?) {
        guard password != nil else { return }
        let alert = NSAlert()
        alert.messageText = "Remove Document Password?"
        alert.informativeText = "The document will be saved unencrypted from now on."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        password = nil
        KeychainPasswordStore.delete(for: model.documentID)
        updateChangeCount(.changeDone)
    }

    private func promptForNewPassword(documentID: UUID) -> String? {
        let alert = NSAlert()
        alert.messageText = "Set Document Password"
        alert.informativeText = "This document's content will be encrypted with this password. There is no way to recover a lost password."
        alert.addButton(withTitle: "Set Password")
        alert.addButton(withTitle: "Cancel")

        let passwordField = NSSecureTextField(frame: NSRect(x: 0, y: 56, width: 280, height: 24))
        passwordField.placeholderString = "Password"
        let confirmField = NSSecureTextField(frame: NSRect(x: 0, y: 28, width: 280, height: 24))
        confirmField.placeholderString = "Confirm Password"
        let rememberCheckbox = NSButton(checkboxWithTitle: "Save in Keychain", target: nil, action: nil)
        rememberCheckbox.frame = NSRect(x: 0, y: 0, width: 280, height: 20)
        rememberCheckbox.state = .on

        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 84))
        accessory.addSubview(passwordField)
        accessory.addSubview(confirmField)
        accessory.addSubview(rememberCheckbox)
        alert.accessoryView = accessory
        alert.window.initialFirstResponder = passwordField

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        guard !passwordField.stringValue.isEmpty, passwordField.stringValue == confirmField.stringValue else {
            let errorAlert = NSAlert()
            errorAlert.messageText = "Passwords Don't Match"
            errorAlert.informativeText = "Enter the same password in both fields."
            errorAlert.runModal()
            return nil
        }
        if rememberCheckbox.state == .on {
            KeychainPasswordStore.save(password: passwordField.stringValue, for: documentID)
        }
        return passwordField.stringValue
    }

    private func promptForExistingPassword(documentID: UUID) -> String? {
        let alert = NSAlert()
        alert.messageText = "Enter Document Password"
        alert.informativeText = "This document is encrypted."
        alert.addButton(withTitle: "Unlock")
        alert.addButton(withTitle: "Cancel")

        let passwordField = NSSecureTextField(frame: NSRect(x: 0, y: 28, width: 280, height: 24))
        passwordField.placeholderString = "Password"
        let rememberCheckbox = NSButton(checkboxWithTitle: "Save in Keychain", target: nil, action: nil)
        rememberCheckbox.frame = NSRect(x: 0, y: 0, width: 280, height: 20)

        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 56))
        accessory.addSubview(passwordField)
        accessory.addSubview(rememberCheckbox)
        alert.accessoryView = accessory
        alert.window.initialFirstResponder = passwordField

        guard alert.runModal() == .alertFirstButtonReturn, !passwordField.stringValue.isEmpty else { return nil }
        if rememberCheckbox.state == .on {
            KeychainPasswordStore.save(password: passwordField.stringValue, for: documentID)
        }
        return passwordField.stringValue
    }
}
