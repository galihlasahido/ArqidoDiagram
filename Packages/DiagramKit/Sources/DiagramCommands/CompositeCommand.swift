import DiagramModel

/// Bundles heterogeneous commands (e.g. duplicate = add nodes + add their
/// edges) into one undo step. Applies in order; inverts in reverse order
/// with each sub-command's own inverse, so undo unwinds exactly like a
/// stack.
public struct CompositeCommand: Command {
    public let commands: [any Command]

    public init(_ commands: [any Command]) {
        self.commands = commands
    }

    public var affectedObjectIDs: [AnyObjectID] {
        commands.flatMap { $0.affectedObjectIDs }
    }

    public func apply(to scene: SceneStore) {
        for command in commands {
            command.apply(to: scene)
        }
    }

    public func inverse() -> any Command {
        CompositeCommand(commands.reversed().map { $0.inverse() })
    }
}
