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

        let envelope: DocumentEncryption.Envelope?
        if let envelopeData = children["encryption.json"]?.regularFileContents {
            envelope = try decoder.decode(DocumentEncryption.Envelope.self, from: envelopeData)
        } else {
            envelope = nil
        }
        if envelope != nil, password == nil {
            throw PackageReadError.encryptionPasswordRequired
        }

        func decoded<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
            guard let envelope, let password else { return try decoder.decode(type, from: data) }
            let plaintext: Data
            do {
                plaintext = try DocumentEncryption.decrypt(data, password: password, envelope: envelope)
            } catch {
                throw PackageReadError.incorrectPassword
            }
            return try decoder.decode(type, from: plaintext)
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
}
