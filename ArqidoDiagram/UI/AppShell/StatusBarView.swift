import SwiftUI

/// The persistent bottom status strip every pane sits above, per the
/// Visual/UI Style requirements — same role as Activity Monitor's own bottom
/// status line. TODO: selection count becomes live once selection (step 7)
/// exists; shown as an honest placeholder (not a fabricated number) until
/// then. Zoom% and object count are already real.
struct StatusBarView: View {
    @ObservedObject var document: DiagramDocument
    @ObservedObject var canvasStatus: CanvasStatusModel

    private var currentPage: (name: String, objectCount: Int) {
        guard let pageID = document.model.pageOrder.first, let page = document.model.pages[pageID] else {
            return ("—", 0)
        }
        return (page.name, page.nodes.count)
    }

    var body: some View {
        HStack(spacing: 16) {
            Text(currentPage.name)
            Spacer()
            Text("Selection: —")
            Text("Objects: \(currentPage.objectCount)")
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
