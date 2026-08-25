import DiagramModel

public struct AddEdgesCommand: Command {
    public let edges: [DiagramEdge]

    public init(edges: [DiagramEdge]) {
        self.edges = edges
    }

    public var affectedObjectIDs: [AnyObjectID] { edges.map { .edge($0.id) } }

    public func apply(to scene: SceneStore) {
        for edge in edges { scene.setEdge(edge) }
    }

    public func inverse() -> any Command {
        RemoveEdgesCommand(edges: edges)
    }
}

public struct RemoveEdgesCommand: Command {
    public let edges: [DiagramEdge]

    public init(edges: [DiagramEdge]) {
        self.edges = edges
    }

    public var affectedObjectIDs: [AnyObjectID] { edges.map { .edge($0.id) } }

    public func apply(to scene: SceneStore) {
        for edge in edges { scene.removeEdge(edge.id) }
    }

    public func inverse() -> any Command {
        AddEdgesCommand(edges: edges)
    }
}

/// Covers reroute/waypoint/style/label changes — the edge counterpart of
/// `UpdateNodesCommand`.
public struct UpdateEdgesCommand: Command {
    public let before: [EdgeID: DiagramEdge]
    public let after: [EdgeID: DiagramEdge]

    public init(before: [EdgeID: DiagramEdge], after: [EdgeID: DiagramEdge]) {
        self.before = before
        self.after = after
    }

    public var affectedObjectIDs: [AnyObjectID] { after.keys.map { .edge($0) } }

    public func apply(to scene: SceneStore) {
        for (_, edge) in after { scene.setEdge(edge) }
    }

    public func inverse() -> any Command {
        UpdateEdgesCommand(before: after, after: before)
    }
}
