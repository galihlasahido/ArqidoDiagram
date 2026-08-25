import SwiftUI
import DiagramModel

/// The persistent bottom status strip — page tabs on the left (per the
/// spec's "Page 1  Page 2  Page 3 ... 100%  +" layout), live selection/
/// object counts and zoom% on the right. Same role as Activity Monitor's
/// own bottom status line.
struct StatusBarView: View {
    @ObservedObject var document: DiagramDocument
    @ObservedObject var canvasStatus: CanvasStatusModel
    @ObservedObject var selection: SelectionModel
    @Binding var activePageID: PageID?

    private var objectCount: Int {
        guard let id = activePageID ?? document.model.pageOrder.first else { return 0 }
        return document.model.pages[id]?.nodes.count ?? 0
    }

    var body: some View {
        HStack(spacing: 16) {
            PageTabsView(document: document, activePageID: $activePageID)
            Spacer()
            Text("Selection: \(selection.selectedNodeIDs.count)")
                .monospacedDigit()
            Text("Objects: \(objectCount)")
                .monospacedDigit()
            Text("\(canvasStatus.zoomPercent)%")
                .monospacedDigit()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
