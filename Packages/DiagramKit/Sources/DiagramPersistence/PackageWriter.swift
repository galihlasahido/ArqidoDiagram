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
    /// `password` is optional — when non-nil, `document.json` and every
    /// page file are AES-GCM-encrypted (see `DocumentEncryption`) and an
    /// `encryption.json` sidecar (salt + iteration count only, never the
    /// password or the derived key) is written alongside them.
    /// `manifest.json` always stays plaintext (see `PackageReader`'s doc
    /// comment on why).
    /// `versions` (spec §VERSIONING) are full document snapshots, saved
    /// under `versions/<uuid>.json` — encrypted the same way as the live
    /// content when `password` is set, since a snapshot can carry exactly
    /// the same sensitive data the current document does.
    public static func fileWrapper(
        for document: DiagramDocumentModel,
        appVersion: String = "0.1.0",
        password: String? = nil,
        versions: [DocumentVersion] = []
    ) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601

        let envelope = password.map { _ in DocumentEncryption.makeEnvelope() }

        func encoded<T: Encodable>(_ value: T) throws -> Data {
            let data = try encoder.encode(value)
            guard let envelope, let password else { return data }
            return try DocumentEncryption.encrypt(data, password: password, envelope: envelope)
        }

        var pageEntries: [ManifestV1.PageEntry] = []
        var pageFileWrappers: [String: FileWrapper] = [:]

        for pageID in document.pageOrder {
            guard let page = document.pages[pageID] else { continue }
            let fileName = "page-\(pageID.raw.uuidString).json"
            let data = try encoded(page)
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
        let infoData = try encoded(info)

        var versionFileWrappers: [String: FileWrapper] = [:]
        for version in versions {
            let data = try encoded(version)
            versionFileWrappers["\(version.id.uuidString).json"] = FileWrapper(regularFileWithContents: data)
        }

        var children: [String: FileWrapper] = [
            "manifest.json": FileWrapper(regularFileWithContents: manifestData),
            "document.json": FileWrapper(regularFileWithContents: infoData),
            "pages": FileWrapper(directoryWithFileWrappers: pageFileWrappers),
            "assets": FileWrapper(directoryWithFileWrappers: [:]),
            "versions": FileWrapper(directoryWithFileWrappers: versionFileWrappers)
        ]
        if let envelope {
            children["encryption.json"] = FileWrapper(regularFileWithContents: try encoder.encode(envelope))
        }
        return FileWrapper(directoryWithFileWrappers: children)
    }
}
