import Foundation
import DiagramModel

/// Bridges "add this shape" from the sidebar (SwiftUI) to the canvas
/// (AppKit): `LibrarySidebarView` sets `pendingType` when a shape row is
/// clicked; `CanvasHostView.updateNSView` consumes it (adds the node at the
/// viewport center, selects it) and clears it back to `nil`.
final class ShapeInsertionRequest: ObservableObject {
    @Published var pendingType: ShapeType?
}
