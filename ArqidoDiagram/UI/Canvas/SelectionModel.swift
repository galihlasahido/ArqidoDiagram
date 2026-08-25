import Foundation
import DiagramModel

/// The small, coarse view-model SwiftUI observes for selection — mirrors
/// `DiagramCanvasView.selection` but as an `ObservableObject` so the status
/// bar (and, from build-order step 12, the Inspector) can bind to it without
/// the canvas itself depending on Combine/SwiftUI.
final class SelectionModel: ObservableObject {
    @Published var selectedNodeIDs: Set<NodeID> = []
    /// Node and edge selection are mutually exclusive (see
    /// `DiagramCanvasView.edgeSelection`'s doc comment) — mirrored here the
    /// same way `selectedNodeIDs` mirrors `DiagramCanvasView.selection`.
    @Published var selectedEdgeIDs: Set<EdgeID> = []
}
