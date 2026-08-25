import DiagramModel

/// A single undoable mutation. Inverses are captured/computed at `apply`
/// time (or at construction, from pre-state), never lazily re-derived at
/// undo time — this is what keeps `inverse()` correct even if unrelated
/// state changed in between.
public protocol Command {
    /// Object IDs touched by this command, for dirty-rect invalidation and
    /// inspector refresh.
    var affectedObjectIDs: [AnyObjectID] { get }

    func apply(to scene: SceneStore)
    func inverse() -> any Command
}

public enum AnyObjectID: Hashable, Sendable {
    case node(NodeID)
    case edge(EdgeID)
    case group(GroupID)
    case page(PageID)
}

// Concrete commands: `UpdateNodesCommand` (move/resize/rotate/style/
// metadata/text/z-order — one generic before/after snapshot command covers
// all of these, replacing what the plan originally sketched as many
// structurally-identical command types), `AddNodesCommand`/
// `RemoveNodesCommand`, `AddEdgesCommand`/`RemoveEdgesCommand`,
// `CompositeCommand`. `CommandStack` wraps `UndoManager`. Page-level
// commands (add/rename/delete/duplicate/reorder page) operate on
// `DiagramDocumentModel` directly rather than through `SceneStore` — a page
// switch is a document-level structural change, not a mutation of the
// currently active page's live scene.
