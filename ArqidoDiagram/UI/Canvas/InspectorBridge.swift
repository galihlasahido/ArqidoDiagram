import Foundation
import DiagramRendering

/// Gives `InspectorView` (a SwiftUI sibling of `CanvasHostView`, not a
/// parent/child) a write path into the live canvas. `CanvasHostView` sets
/// `canvasView` in `makeNSView`; edits go through
/// `DiagramCanvasView.updateSelectedNodes(actionName:_:)` so Inspector
/// edits are undoable exactly like canvas-driven edits, through the same
/// single Command entry point.
final class InspectorBridge: ObservableObject {
    weak var canvasView: DiagramCanvasView?
}
