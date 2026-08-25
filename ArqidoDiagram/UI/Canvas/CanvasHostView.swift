import SwiftUI
import DiagramRendering

/// Thin `NSViewRepresentable` bridge to `DiagramRendering.DiagramCanvasView`
/// — the real NSView-backed Core Graphics canvas, per the Visual/UI Style
/// requirements. This file only wires SwiftUI state in and zoom% out; all
/// drawing/hit-testing/spatial-index logic lives in `DiagramRendering`,
/// which has no SwiftUI import.
struct CanvasHostView: NSViewRepresentable {
    @ObservedObject var document: DiagramDocument
    @ObservedObject var status: CanvasStatusModel

    func makeNSView(context: Context) -> DiagramCanvasView {
        let view = DiagramCanvasView()
        view.onViewportChange = { viewport in
            status.zoomPercent = Int((viewport.scale * 100).rounded())
        }
        loadCurrentPage(into: view)
        return view
    }

    func updateNSView(_ nsView: DiagramCanvasView, context: Context) {
        loadCurrentPage(into: nsView)
    }

    private func loadCurrentPage(into view: DiagramCanvasView) {
        guard let pageID = document.model.pageOrder.first, let page = document.model.pages[pageID] else {
            view.loadNodes([])
            return
        }
        view.loadNodes(Array(page.nodes.values))
    }
}
