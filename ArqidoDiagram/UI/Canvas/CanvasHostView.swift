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
    @ObservedObject var inspectorBridge: InspectorBridge
    @ObservedObject var componentStore: CustomComponentStore
    @ObservedObject var connectorStyle: ConnectorStyleModel
    @Binding var activePageID: PageID?

    private var resolvedPageID: PageID? { activePageID ?? document.model.pageOrder.first }

    func makeNSView(context: Context) -> DiagramCanvasView {
        let view = DiagramCanvasView()
        view.documentUndoManager = document.undoManager
        view.onViewportChange = { viewport in
            status.zoomPercent = Int((viewport.scale * 100).rounded())
        }
        view.onSelectionChange = { ids in
            selection.selectedNodeIDs = ids
        }
        view.onEdgeSelectionChange = { ids in
            selection.selectedEdgeIDs = ids
        }
        view.onSceneChanged = { [weak view] in
            guard let view else { return }
            writeBack(from: view)
        }
        view.onExportRequested = { [weak view] page, format in
            ExportCoordinator.presentSavePanelAndExport(page: page, format: format, window: view?.window)
        }
        view.onCopyAsSVGRequested = { page in
            ExportCoordinator.copyAsSVG(page: page)
        }
        view.onTextExportRequested = { [weak view] page, format in
            InteropCoordinator.presentSavePanelAndExportText(page: page, format: format, architectureName: document.model.title, window: view?.window)
        }
        view.onImportRequested = { [weak view] in
            InteropCoordinator.presentOpenPanelAndImport(canvasView: view, window: view?.window)
        }
        view.onComponentSaved = { component in
            componentStore.save(component)
        }
        inspectorBridge.canvasView = view
        loadCurrentPage(into: view, coordinator: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: DiagramCanvasView, context: Context) {
        loadCurrentPage(into: nsView, coordinator: context.coordinator)
        // Selection is canvas-owned during canvas interaction; this only
        // matters once something else (Inspector, search) starts writing
        // into `selection` — `applyExternalSelection` no-ops otherwise.
        nsView.applyExternalSelection(selection.selectedNodeIDs)
        nsView.applyExternalEdgeSelection(selection.selectedEdgeIDs)
        nsView.defaultRoutingStyle = connectorStyle.routingStyle

        if let pending = shapeInsertion.pending {
            nsView.addNode(ofType: pending.shapeType, iconType: pending.iconType, text: pending.text)
            shapeInsertion.pending = nil
        }
        if let component = shapeInsertion.pendingComponent {
            nsView.insertComponent(component)
            shapeInsertion.pendingComponent = nil
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// Tracks the last-loaded page ID purely so switching pages can also
    /// re-fit the viewport to the new page's content (a fresh page's
    /// content is a different size/position than the one just left).
    final class Coordinator {
        var lastLoadedPageID: PageID?
    }

    private func loadCurrentPage(into view: DiagramCanvasView, coordinator: Coordinator) {
        guard let pageID = resolvedPageID, let page = document.model.pages[pageID] else {
            view.loadPage(DiagramPage(name: "", order: 0))
            return
        }
        view.loadPage(page)
        if coordinator.lastLoadedPageID != pageID {
            coordinator.lastLoadedPageID = pageID
            view.fitToScreen()
        }
    }

    private func writeBack(from view: DiagramCanvasView) {
        guard let pageID = resolvedPageID, let existing = document.model.pages[pageID] else { return }
        let updated = view.currentPageSnapshot(
            name: existing.name,
            order: existing.order,
            canvasSize: existing.canvasSize,
            background: existing.background
        )
        document.updatePage(updated)
    }
}
