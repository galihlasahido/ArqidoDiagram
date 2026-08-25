import Foundation
import DiagramModel

/// Builds the on-disk `.diagram` package as a `FileWrapper` tree.
///
/// The whole tree is built in memory before being returned — never by
/// mutating an existing on-disk wrapper in place — so a failure partway
/// through (e.g. an asset that fails to encode) leaves the previously-saved
/// package completely untouched, and `NSDocument`'s save call surfaces the
/// thrown error instead of silently reporting success. `NSDocument`'s
/// standard package-write behavior (temp file + atomic rename into place)
/// handles the on-disk atomicity on top of this.
///
/// TODO(Phase 1, build-order step 18): only replace `FileWrapper` children
/// for pages tracked dirty by `CommandStack`, instead of rebuilding every
/// page's wrapper on every save — needed once `DiagramCommands` exists.
public enum PackageWriter {
    public static func fileWrapper(for document: DiagramDocumentModel, appVersion: String = "0.1.0") throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601

        var pageEntries: [ManifestV1.PageEntry] = []
        var pageFileWrappers: [String: FileWrapper] = [:]

        for pageID in document.pageOrder {
            guard let page = document.pages[pageID] else { continue }
            let fileName = "page-\(pageID.raw.uuidString).json"
            let data = try encoder.encode(page)
            pageFileWrappers[fileName] = FileWrapper(regularFileWithContents: data)
            pageEntries.append(ManifestV1.PageEntry(id: pageID, fileName: fileName, name: page.name))
        }

        let manifest = ManifestV1(
            schemaVersion: document.schemaVersion,
            appVersion: appVersion,
            documentID: document.documentID,
            pageOrder: document.pageOrder,
            pages: pageEntries
        )
        let manifestData = try encoder.encode(manifest)

        let info = DocumentInfo(title: document.title, createdAt: document.createdAt, modifiedAt: document.modifiedAt)
        let infoData = try encoder.encode(info)

        return FileWrapper(directoryWithFileWrappers: [
            "manifest.json": FileWrapper(regularFileWithContents: manifestData),
            "document.json": FileWrapper(regularFileWithContents: infoData),
            "pages": FileWrapper(directoryWithFileWrappers: pageFileWrappers),
            "assets": FileWrapper(directoryWithFileWrappers: [:])
        ])
    }
}
