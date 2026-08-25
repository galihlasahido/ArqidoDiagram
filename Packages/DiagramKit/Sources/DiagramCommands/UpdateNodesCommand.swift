import DiagramModel

/// Covers move, resize, rotate, style, metadata, text-edit, and z-order
/// changes — anything that's just "these nodes had these values before,
/// these after." One generic before/after snapshot command replaces what
/// would otherwise be many structurally-identical single-purpose command
/// types.
public struct UpdateNodesCommand: Command {
    public let before: [NodeID: DiagramNode]
    public let after: [NodeID: DiagramNode]

    public init(before: [NodeID: DiagramNode], after: [NodeID: DiagramNode]) {
        self.before = before
        self.after = after
    }

    public var affectedObjectIDs: [AnyObjectID] { after.keys.map { .node($0) } }

    public func apply(to scene: SceneStore) {
        for (_, node) in after {
            scene.setNode(node)
        }
    }

    public func inverse() -> any Command {
        UpdateNodesCommand(before: after, after: before)
    }
}
