import DiagramModel

public struct AddNodesCommand: Command {
    public let nodes: [DiagramNode]

    public init(nodes: [DiagramNode]) {
        self.nodes = nodes
    }

    public var affectedObjectIDs: [AnyObjectID] { nodes.map { .node($0.id) } }

    public func apply(to scene: SceneStore) {
        for node in nodes { scene.setNode(node) }
    }

    public func inverse() -> any Command {
        RemoveNodesCommand(nodes: nodes)
    }
}

public struct RemoveNodesCommand: Command {
    public let nodes: [DiagramNode]

    public init(nodes: [DiagramNode]) {
        self.nodes = nodes
    }

    public var affectedObjectIDs: [AnyObjectID] { nodes.map { .node($0.id) } }

    public func apply(to scene: SceneStore) {
        for node in nodes { scene.removeNode(node.id) }
    }

    public func inverse() -> any Command {
        AddNodesCommand(nodes: nodes)
    }
}
