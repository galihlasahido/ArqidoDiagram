import DiagramModel

public struct GroupNodesCommand: Command {
    public let group: DiagramGroup
    /// Each member's `groupID` before grouping (nil if it was ungrouped),
    /// so ungrouping restores prior nested-group membership rather than
    /// always clearing it.
    public let previousGroupIDs: [NodeID: GroupID?]

    public init(group: DiagramGroup, previousGroupIDs: [NodeID: GroupID?]) {
        self.group = group
        self.previousGroupIDs = previousGroupIDs
    }

    public var affectedObjectIDs: [AnyObjectID] {
        [.group(group.id)] + group.memberNodeIDs.map { .node($0) }
    }

    public func apply(to scene: SceneStore) {
        scene.setGroup(group)
        for id in group.memberNodeIDs {
            guard var node = scene.nodes[id] else { continue }
            node.groupID = group.id
            scene.setNode(node)
        }
    }

    public func inverse() -> any Command {
        UngroupNodesCommand(group: group, previousGroupIDs: previousGroupIDs)
    }
}

public struct UngroupNodesCommand: Command {
    public let group: DiagramGroup
    public let previousGroupIDs: [NodeID: GroupID?]

    public init(group: DiagramGroup, previousGroupIDs: [NodeID: GroupID?]) {
        self.group = group
        self.previousGroupIDs = previousGroupIDs
    }

    public var affectedObjectIDs: [AnyObjectID] {
        [.group(group.id)] + group.memberNodeIDs.map { .node($0) }
    }

    public func apply(to scene: SceneStore) {
        scene.removeGroup(group.id)
        for id in group.memberNodeIDs {
            guard var node = scene.nodes[id] else { continue }
            node.groupID = previousGroupIDs[id] ?? nil
            scene.setNode(node)
        }
    }

    public func inverse() -> any Command {
        GroupNodesCommand(group: group, previousGroupIDs: previousGroupIDs)
    }
}
