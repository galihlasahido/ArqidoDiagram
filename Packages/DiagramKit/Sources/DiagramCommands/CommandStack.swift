import Foundation
import DiagramModel

/// Wraps `UndoManager` (from `NSDocument.undoManager`) around `SceneStore`
/// mutations. `perform(_:actionName:)` is the single committed-mutation
/// entry point every command goes through — this is what undo correctness
/// relies on (see `Command`'s doc comment on inverses being captured at
/// apply time, not re-derived later).
///
/// Live gesture preview (an in-progress drag, before the user releases the
/// mouse) is the one narrow, intentional exception to "always go through a
/// Command": `DiagramCanvasView` mutates `SceneStore` directly for
/// per-frame visual feedback during a drag, then commits exactly one
/// `UpdateNodesCommand` here at gesture end representing the net start ->
/// end change. This matches the plan's own performance guidance (batch a
/// whole gesture into one committed step, not one command per mouse-move
/// event) without registering hundreds of intermediate undo steps.
public final class CommandStack {
    private let scene: SceneStore
    public var undoManager: UndoManager?

    public init(scene: SceneStore, undoManager: UndoManager? = nil) {
        self.scene = scene
        self.undoManager = undoManager
    }

    public func perform(_ command: any Command, actionName: String) {
        command.apply(to: scene)
        if let undoManager {
            undoManager.registerUndo(withTarget: self) { stack in
                stack.perform(command.inverse(), actionName: actionName)
            }
            undoManager.setActionName(actionName)
        }
    }
}
