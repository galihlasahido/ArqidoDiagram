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

    override init() {
        model = .blank(at: Date())
        super.init()
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
        return try PackageWriter.fileWrapper(for: model)
    }

    override func read(from fileWrapper: FileWrapper, ofType typeName: String) throws {
        model = try PackageReader.documentModel(from: fileWrapper)
    }

    override func canAsynchronouslyWrite(
        to url: URL,
        ofType typeName: String,
        for saveOperation: NSDocument.SaveOperationType
    ) -> Bool {
        true
    }
}
