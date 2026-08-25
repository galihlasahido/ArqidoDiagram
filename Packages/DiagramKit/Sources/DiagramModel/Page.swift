import Foundation

public struct PageBackground: Codable, Hashable, Sendable {
    public var color: ColorRef?
    public var showGrid: Bool

    public init(color: ColorRef? = nil, showGrid: Bool = true) {
        self.color = color
        self.showGrid = showGrid
    }
}

/// Flat dictionaries keyed by ID, plus explicit ordered z-order arrays — not
/// a tree. O(1) ID lookup is needed constantly (selection, hit-testing, undo
/// targeting, inspector binding); grouping/containment is expressed via ID
/// references (`DiagramNode.groupID`, `DiagramGroup.memberNodeIDs`), not
/// physical nesting.
public struct DiagramPage: Codable, Identifiable, Sendable {
    public var id: PageID
    public var name: String
    public var order: Int
    /// `nil` means infinite/unbounded canvas.
    public var canvasSize: Size2D?
    public var background: PageBackground

    public var nodes: [NodeID: DiagramNode]
    public var edges: [EdgeID: DiagramEdge]
    public var groups: [GroupID: DiagramGroup]

    /// Back-to-front draw/hit-test order.
    public var nodeZOrder: [NodeID]
    public var edgeZOrder: [EdgeID]

    public init(
        id: PageID = PageID(),
        name: String,
        order: Int,
        canvasSize: Size2D? = nil,
        background: PageBackground = PageBackground(),
        nodes: [NodeID: DiagramNode] = [:],
        edges: [EdgeID: DiagramEdge] = [:],
        groups: [GroupID: DiagramGroup] = [:],
        nodeZOrder: [NodeID] = [],
        edgeZOrder: [EdgeID] = []
    ) {
        self.id = id
        self.name = name
        self.order = order
        self.canvasSize = canvasSize
        self.background = background
        self.nodes = nodes
        self.edges = edges
        self.groups = groups
        self.nodeZOrder = nodeZOrder
        self.edgeZOrder = edgeZOrder
    }
}
