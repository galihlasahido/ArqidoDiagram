/// Not implemented yet. Reserved for tool state machines (`SelectTool`,
/// `MoveTool`, `ResizeTool`, `DrawConnectorTool`, `TextEditTool`) that own
/// `SceneStore` mutation entry points and drive them exclusively through
/// `DiagramCommands` (never a direct-mutation path) so undo/redo stays
/// consistent regardless of which UI surface triggered a change.
///
/// Lands starting at Phase 1 build-order step 6 (selection) and step 8
/// (move via command).
public enum DiagramInteractionModule {}
