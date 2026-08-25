import Foundation
import DiagramModel

/// Mirrors `manifest.json` inside a `.diagram` package: schema version, page
/// index (id/name/file only — lets the page list load fast without parsing
/// every page's full content), document identity.
public struct ManifestV1: Codable, Sendable {
    public struct PageEntry: Codable, Sendable {
        public var id: PageID
        public var fileName: String
        public var name: String

        public init(id: PageID, fileName: String, name: String) {
            self.id = id
            self.fileName = fileName
            self.name = name
        }
    }

    public var schemaVersion: Int
    public var appVersion: String
    public var documentID: UUID
    public var pageOrder: [PageID]
    public var pages: [PageEntry]

    public init(schemaVersion: Int, appVersion: String, documentID: UUID, pageOrder: [PageID], pages: [PageEntry]) {
        self.schemaVersion = schemaVersion
        self.appVersion = appVersion
        self.documentID = documentID
        self.pageOrder = pageOrder
        self.pages = pages
    }
}

/// Mirrors `document.json` inside a `.diagram` package: document-level
/// metadata, deliberately kept separate from page content.
public struct DocumentInfo: Codable, Sendable {
    public var title: String
    public var createdAt: Date
    public var modifiedAt: Date

    public init(title: String, createdAt: Date, modifiedAt: Date) {
        self.title = title
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}
