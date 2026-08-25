import Foundation
import DiagramModel

/// One pending "add this to the canvas" request — either a plain shape or a
/// technology icon badge (container shape + `TechIconType` + a name label).
struct PendingInsertion {
    var shapeType: ShapeType
    var iconType: TechIconType?
    var text: String?
}

/// Bridges "add this shape" from the sidebar (SwiftUI) to the canvas
/// (AppKit): `LibrarySidebarView` sets `pending`/`pendingComponent` when a
/// shape/icon row or a saved component is clicked; `CanvasHostView.
/// updateNSView` consumes whichever is set (adds it at the viewport center,
/// selects it) and clears it back to `nil`.
final class ShapeInsertionRequest: ObservableObject {
    @Published var pending: PendingInsertion?
    @Published var pendingComponent: CustomComponent?
}
