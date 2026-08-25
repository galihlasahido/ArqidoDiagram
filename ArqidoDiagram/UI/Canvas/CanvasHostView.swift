import SwiftUI
import DiagramModel
import DiagramRendering

/// Thin `NSViewRepresentable` bridge to `DiagramRendering.DiagramCanvasView`
/// — the real NSView-backed Core Graphics canvas, per the Visual/UI Style
/// requirements. This file only wires SwiftUI state in and zoom%/selection/
/// scene-changes out; all drawing/hit-testing/spatial-index/command logic
/// lives in `DiagramRendering`+`DiagramCommands`, which have no SwiftUI
/// import.
struct CanvasHostView: NSViewRepresentable {
    @ObservedObject var document: DiagramDocument
    @ObservedObject var status: CanvasStatusModel
    @ObservedObject var selection: SelectionModel
    @ObservedObject var shapeInsertion: ShapeInsertionRequest

    func makeNSView(context: Context) -> DiagramCanvasView {
        let view = DiagramCanvasView()
        view.documentUndoManager = document.undoManager
        view.onViewportChange = { viewport in
            status.zoomPercent = Int((viewport.scale * 100).rounded())
        }
        view.onSelectionChange = { ids in
            selection.selectedNodeIDs = ids
        }
        view.onSceneChanged = { [weak view] in
            guard let view else { return }
            writeBack(from: view)
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

        if let type = shapeInsertion.pendingType {
            nsView.addNode(ofType: type)
            shapeInsertion.pendingType = nil
        }
    }

    private func loadCurrentPage(into view: DiagramCanvasView) {
        guard let pageID = document.model.pageOrder.first, let page = document.model.pages[pageID] else {
            view.loadPage(DiagramPage(name: "", order: 0))
            return
        }
        view.loadPage(page)
    }

    private func writeBack(from view: DiagramCanvasView) {
        guard let pageID = document.model.pageOrder.first, let existing = document.model.pages[pageID] else { return }
        let updated = view.currentPageSnapshot(
            name: existing.name,
            order: existing.order,
            canvasSize: existing.canvasSize,
            background: existing.background
        )
        document.updatePage(updated)
    }
}
