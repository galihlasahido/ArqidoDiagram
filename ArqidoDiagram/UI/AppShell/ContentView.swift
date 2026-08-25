import SwiftUI

struct ContentView: View {
    @ObservedObject var document: DiagramDocument

    var body: some View {
        NavigationSplitView {
            LibrarySidebarView()
        } content: {
            CanvasHostView()
                .navigationTitle(document.model.title)
        } detail: {
            InspectorView()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StatusBarView(document: document)
        }
    }
}
