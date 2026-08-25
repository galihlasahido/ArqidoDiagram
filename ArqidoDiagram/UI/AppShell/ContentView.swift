import SwiftUI
import DiagramModel

struct ContentView: View {
    @ObservedObject var document: DiagramDocument
    @StateObject private var canvasStatus = CanvasStatusModel()
    @StateObject private var selection = SelectionModel()
    @StateObject private var shapeInsertion = ShapeInsertionRequest()
    @StateObject private var inspectorBridge = InspectorBridge()
    @StateObject private var searchModel = SearchModel()
    @State private var activePageID: PageID?

    var body: some View {
        NavigationSplitView {
            LibrarySidebarView(shapeInsertion: shapeInsertion)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } content: {
            // Explicitly given no ideal width so it absorbs whatever the
            // sidebar/inspector columns don't claim — the canvas, not the
            // inspector, should be the pane that expands.
            CanvasHostView(
                document: document,
                status: canvasStatus,
                selection: selection,
                shapeInsertion: shapeInsertion,
                inspectorBridge: inspectorBridge,
                activePageID: $activePageID
            )
            .navigationSplitViewColumnWidth(min: 400, ideal: 900)
            .navigationTitle(document.model.title)
            .overlay(alignment: .top) {
                if searchModel.isPresented {
                    SearchOverlayView(document: document, searchModel: searchModel, bridge: inspectorBridge, activePageID: $activePageID)
                        .padding(.top, 12)
                }
            }
        } detail: {
            InspectorView(document: document, selection: selection, bridge: inspectorBridge)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StatusBarView(document: document, canvasStatus: canvasStatus, selection: selection, activePageID: $activePageID)
        }
        .onAppear {
            if activePageID == nil { activePageID = document.model.pageOrder.first }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSearch)) { _ in
            searchModel.isPresented.toggle()
        }
    }
}
