import Foundation
import DiagramModel

public enum PackageReadError: Error, Equatable {
    case notAPackage
    case missingManifest
    case missingDocumentInfo
    case missingPagesDirectory
    case missingPageFile(String)
}

public enum PackageReader {
    public static func documentModel(from wrapper: FileWrapper) throws -> DiagramDocumentModel {
        guard wrapper.isDirectory, let children = wrapper.fileWrappers else {
            throw PackageReadError.notAPackage
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let manifestData = children["manifest.json"]?.regularFileContents else {
            throw PackageReadError.missingManifest
        }
        let manifest = try MigrationRegistry.migrate(try decoder.decode(ManifestV1.self, from: manifestData))

        guard let infoData = children["document.json"]?.regularFileContents else {
            throw PackageReadError.missingDocumentInfo
        }
        let info = try decoder.decode(DocumentInfo.self, from: infoData)

        guard let pageWrappers = children["pages"]?.fileWrappers else {
            throw PackageReadError.missingPagesDirectory
        }

        var pages: [PageID: DiagramPage] = [:]
        for entry in manifest.pages {
            guard let data = pageWrappers[entry.fileName]?.regularFileContents else {
                throw PackageReadError.missingPageFile(entry.fileName)
            }
            pages[entry.id] = try decoder.decode(DiagramPage.self, from: data)
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
