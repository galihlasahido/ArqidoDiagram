import Foundation
import DiagramModel

public enum PackageReadError: Error, Equatable {
    case notAPackage
    case missingManifest
    case missingDocumentInfo
    case missingPagesDirectory
    case missingPageFile(String)
    /// The package has an `encryption.json` sidecar (see `PackageWriter`)
    /// but no password was supplied to decrypt it.
    case encryptionPasswordRequired
    case incorrectPassword
}

public enum PackageReader {
    /// Reads only `manifest.json` (always plaintext) to answer "whose
    /// document is this, and is it encrypted" — enough for a caller to
    /// check the Keychain or prompt for a password *before* attempting the
    /// full, possibly-encrypted `documentModel(from:password:)` read.
    public static func peekManifest(from wrapper: FileWrapper) throws -> (documentID: UUID, isEncrypted: Bool) {
        guard wrapper.isDirectory, let children = wrapper.fileWrappers else {
            throw PackageReadError.notAPackage
        }
        guard let manifestData = children["manifest.json"]?.regularFileContents else {
            throw PackageReadError.missingManifest
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(ManifestV1.self, from: manifestData)
        return (manifest.documentID, children["encryption.json"] != nil)
    }

    /// `manifest.json` (schema version, document id, page order/names) is
    /// always plaintext, even for an encrypted document — it has to be
    /// readable before a password can even be requested (the password
    /// prompt needs the document identity to check Keychain first). Only
    /// `document.json` and each page's content are ever encrypted; that
    /// plaintext-metadata/encrypted-content split is a deliberate,
    /// documented scope line, not an oversight.
    public static func documentModel(from wrapper: FileWrapper, password: String? = nil) throws -> DiagramDocumentModel {
        guard wrapper.isDirectory, let children = wrapper.fileWrappers else {
            throw PackageReadError.notAPackage
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let manifestData = children["manifest.json"]?.regularFileContents else {
            throw PackageReadError.missingManifest
        }
        let manifest = try MigrationRegistry.migrate(try decoder.decode(ManifestV1.self, from: manifestData))

        let envelope = try readEnvelope(children: children, password: password, decoder: decoder)

        func decoded<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
            try decode(type, from: data, envelope: envelope, password: password, decoder: decoder)
        }

        guard let infoData = children["document.json"]?.regularFileContents else {
            throw PackageReadError.missingDocumentInfo
        }
        let info = try decoded(DocumentInfo.self, from: infoData)

        guard let pageWrappers = children["pages"]?.fileWrappers else {
            throw PackageReadError.missingPagesDirectory
        }

        var pages: [PageID: DiagramPage] = [:]
        for entry in manifest.pages {
            guard let data = pageWrappers[entry.fileName]?.regularFileContents else {
                throw PackageReadError.missingPageFile(entry.fileName)
            }
            pages[entry.id] = try decoded(DiagramPage.self, from: data)
        }

        return DiagramDocumentModel(
            schemaVersion: manifest.schemaVersion,
            documentID: manifest.documentID,
            title: info.title,
            createdAt: info.createdAt,
            modifiedAt: info.modifiedAt,
            pages: pages,
            pageOrder: manifest.pageOrder
        )
    }

    /// Reads back every saved `DocumentVersion` (see `PackageWriter`'s
    /// `versions:` parameter). Order is not guaranteed by the file system,
    /// so callers should sort by `createdAt` themselves if display order
    /// matters (`DiagramDocument` does, newest-first).
    public static func versions(from wrapper: FileWrapper, password: String? = nil) throws -> [DocumentVersion] {
        guard wrapper.isDirectory, let children = wrapper.fileWrappers else {
            throw PackageReadError.notAPackage
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try readEnvelope(children: children, password: password, decoder: decoder)

        guard let versionWrappers = children["versions"]?.fileWrappers else { return [] }
        return try versionWrappers.values.compactMap { fileWrapper in
            guard let data = fileWrapper.regularFileContents else { return nil }
            return try decode(DocumentVersion.self, from: data, envelope: envelope, password: password, decoder: decoder)
        }
    }

    /// Reads back every saved `ArchitectureDecisionRecord` (see
    /// `PackageWriter`'s `adrs:` parameter). Missing `adrs.json` (every
    /// document before this feature existed, or one with no ADRs yet)
    /// yields an empty array rather than throwing.
    public static func adrs(from wrapper: FileWrapper, password: String? = nil) throws -> [ArchitectureDecisionRecord] {
        guard wrapper.isDirectory, let children = wrapper.fileWrappers else {
            throw PackageReadError.notAPackage
        }
        guard let data = children["adrs.json"]?.regularFileContents else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try readEnvelope(children: children, password: password, decoder: decoder)
        return try decode([ArchitectureDecisionRecord].self, from: data, envelope: envelope, password: password, decoder: decoder)
    }

    private static func readEnvelope(children: [String: FileWrapper], password: String?, decoder: JSONDecoder) throws -> DocumentEncryption.Envelope? {
        guard let envelopeData = children["encryption.json"]?.regularFileContents else { return nil }
        let envelope = try decoder.decode(DocumentEncryption.Envelope.self, from: envelopeData)
        if password == nil { throw PackageReadError.encryptionPasswordRequired }
        return envelope
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data, envelope: DocumentEncryption.Envelope?, password: String?, decoder: JSONDecoder) throws -> T {
        guard let envelope, let password else { return try decoder.decode(type, from: data) }
        let plaintext: Data
        do {
            plaintext = try DocumentEncryption.decrypt(data, password: password, envelope: envelope)
        } catch {
            throw PackageReadError.incorrectPassword
        }
        return try decoder.decode(type, from: plaintext)
    }
}
