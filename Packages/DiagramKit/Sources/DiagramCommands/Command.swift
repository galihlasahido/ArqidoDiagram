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

// TODO(Phase 1, build-order step 8): concrete commands
// (Add/Delete/Move/Resize/Rotate/EditText/SetStyle/SetMetadataField/AddEdge/
// RerouteEdge/Group/Ungroup/Align/Distribute/ReorderZ/page commands) and
// `CommandStack` (wraps `UndoManager`) land here once the canvas/interaction
// layer needs them. Not implemented yet — this file only establishes the
// `Command` seam so `DiagramInteraction` and the app target can depend on a
// stable protocol from the start.
