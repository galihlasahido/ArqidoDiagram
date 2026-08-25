import Foundation

/// A reusable saved selection — the spec's "group objects, save selection
/// as component, name/categorize/search/reuse". `nodes`/`edges` are stored
/// with positions relative to the captured selection's bounding-box origin
/// (top-left = (0,0)), so `reuse` can drop the component anywhere without
/// remembering where it was first drawn. Only edges with both endpoints
/// inside the captured selection are kept — an edge reaching outside the
/// selection has no meaningful "relative" endpoint to reattach to on reuse.
public struct CustomComponent: Codable, Identifiable, Sendable {
    public var id: CustomComponentID
    public var name: String
    public var category: String
    public var createdAt: Date
    public var nodes: [DiagramNode]
    public var edges: [DiagramEdge]

    public init(
        id: CustomComponentID = CustomComponentID(),
        name: String,
        category: String,
        createdAt: Date = Date(),
        nodes: [DiagramNode],
        edges: [DiagramEdge]
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.createdAt = createdAt
        self.nodes = nodes
        self.edges = edges
    }

    public var boundingSize: Size2D {
        guard !nodes.isEmpty else { return Size2D(width: 0, height: 0) }
        let maxX = nodes.map { $0.position.x + $0.size.width }.max() ?? 0
        let maxY = nodes.map { $0.position.y + $0.size.height }.max() ?? 0
        return Size2D(width: maxX, height: maxY)
    }
}
