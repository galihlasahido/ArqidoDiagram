import SwiftUI

struct ContentView: View {
    @ObservedObject var document: DiagramDocument
    @StateObject private var canvasStatus = CanvasStatusModel()

    var body: some View {
        NavigationSplitView {
            LibrarySidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } content: {
            // Explicitly given no ideal width so it absorbs whatever the
            // sidebar/inspector columns don't claim — the canvas, not the
            // inspector, should be the pane that expands.
            CanvasHostView(document: document, status: canvasStatus)
                .navigationSplitViewColumnWidth(min: 400, ideal: 900)
                .navigationTitle(document.model.title)
        } detail: {
            InspectorView()
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StatusBarView(document: document, canvasStatus: canvasStatus)
        }
    }
}
