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
