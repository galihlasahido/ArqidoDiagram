import Foundation

/// The small, coarse view-model SwiftUI observes for canvas-derived status
/// (zoom%) — never the canvas's own node data, which stays owned by
/// `DiagramCanvasView` and is pushed here only via `onViewportChange`.
final class CanvasStatusModel: ObservableObject {
    @Published var zoomPercent: Int = 100
}
