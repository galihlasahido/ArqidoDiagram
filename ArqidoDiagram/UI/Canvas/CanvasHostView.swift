import SwiftUI
import DiagramRendering

/// Thin `NSViewRepresentable` bridge to `DiagramRendering.DiagramCanvasView`
/// — the real NSView-backed Core Graphics canvas, per the Visual/UI Style
/// requirements. This file only wires SwiftUI state in and zoom%/selection
/// out; all drawing/hit-testing/spatial-index logic lives in
/// `DiagramRendering`, which has no SwiftUI import.
struct CanvasHostView: NSViewRepresentable {
    @ObservedObject var document: DiagramDocument
    @ObservedObject var status: CanvasStatusModel
    @ObservedObject var selection: SelectionModel

    func makeNSView(context: Context) -> DiagramCanvasView {
        let view = DiagramCanvasView()
        view.onViewportChange = { viewport in
            status.zoomPercent = Int((viewport.scale * 100).rounded())
        }
        view.onSelectionChange = { ids in
            selection.selectedNodeIDs = ids
        }
        loadCurrentPage(into: view)
        return view
    }

    func updateNSView(_ nsView: DiagramCanvasView, context: Context) {
        loadCurrentPage(into: nsView)
        // Selection is canvas-owned during canvas interaction; this only
        // matters once something else (Inspector, search) starts writing
        // into `selection` — `applyExternalSelection` no-ops otherwise.
        nsView.applyExternalSelection(selection.selectedNodeIDs)
    }

    private func loadCurrentPage(into view: DiagramCanvasView) {
        guard let pageID = document.model.pageOrder.first, let page = document.model.pages[pageID] else {
            view.loadNodes([])
            return
        }
        view.loadNodes(Array(page.nodes.values))
    }
}
