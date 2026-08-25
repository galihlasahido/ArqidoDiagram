import SwiftUI
import DiagramModel

struct ContentView: View {
    @ObservedObject var document: DiagramDocument
    @StateObject private var canvasStatus = CanvasStatusModel()
    @StateObject private var selection = SelectionModel()
    @StateObject private var shapeInsertion = ShapeInsertionRequest()
    @StateObject private var inspectorBridge = InspectorBridge()
    @StateObject private var searchModel = SearchModel()
    @StateObject private var componentStore = CustomComponentStore()
    @StateObject private var validationModel = ValidationModel()
    @StateObject private var validationStore = ValidationStore()
    @StateObject private var versionHistoryModel = VersionHistoryModel()
    @StateObject private var aiCommandBarModel = AICommandBarModel()
    @StateObject private var aiConfigurationStore = AIConfigurationStore()
    @StateObject private var adrModel = ADRModel()
    @State private var activePageID: PageID?

    var body: some View {
        NavigationSplitView {
            LibrarySidebarView(shapeInsertion: shapeInsertion, componentStore: componentStore)
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
                componentStore: componentStore,
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
            .overlay(alignment: .topTrailing) {
                if validationModel.isPresented {
                    ValidationPanelView(document: document, validationModel: validationModel, store: validationStore, bridge: inspectorBridge, activePageID: $activePageID)
                        .padding(12)
                } else if versionHistoryModel.isPresented {
                    VersionHistoryPanelView(document: document, versionHistoryModel: versionHistoryModel)
                        .padding(12)
                } else if adrModel.isPresented {
                    ADRPanelView(document: document, adrModel: adrModel, selection: selection)
                        .padding(12)
                }
            }
            .overlay(alignment: .top) {
                if aiCommandBarModel.isPresented {
                    AICommandBarView(document: document, commandBarModel: aiCommandBarModel, configStore: aiConfigurationStore, bridge: inspectorBridge, activePageID: $activePageID)
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
        .onReceive(NotificationCenter.default.publisher(for: .toggleValidation)) { _ in
            validationModel.isPresented.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleVersionHistory)) { _ in
            versionHistoryModel.isPresented.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleAICommandBar)) { _ in
            aiCommandBarModel.isPresented.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleADRPanel)) { _ in
            adrModel.isPresented.toggle()
        }
    }
}
