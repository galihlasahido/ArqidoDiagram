import Foundation

/// The whole-document scene graph: Document -> Page -> Nodes/Edges/Groups.
/// Mirrors `manifest.json` + `pages/*.json` on disk (see DiagramPersistence).
public struct DiagramDocumentModel: Codable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var documentID: UUID
    public var title: String
    public var createdAt: Date
    public var modifiedAt: Date

    public var pages: [PageID: DiagramPage]
    public var pageOrder: [PageID]

    public init(
        schemaVersion: Int = DiagramDocumentModel.currentSchemaVersion,
        documentID: UUID = UUID(),
        title: String,
        createdAt: Date,
        modifiedAt: Date,
        pages: [PageID: DiagramPage] = [:],
        pageOrder: [PageID] = []
    ) {
        self.schemaVersion = schemaVersion
        self.documentID = documentID
        self.title = title
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.pages = pages
        self.pageOrder = pageOrder
    }

    /// A brand-new document: one empty "Page 1", matching "Create a new
    /// document" / "Display an infinite canvas" from the Definition of Done.
    public static func blank(title: String = "Untitled", at date: Date) -> DiagramDocumentModel {
        let page = DiagramPage(name: "Page 1", order: 0)
        return DiagramDocumentModel(
            title: title,
            createdAt: date,
            modifiedAt: date,
            pages: [page.id: page],
            pageOrder: [page.id]
        )
    }
}
