import SwiftUI

/// The persistent bottom status strip every pane sits above, per the
/// Visual/UI Style requirements — same role as Activity Monitor's own bottom
/// status line. TODO: selection count / object count / zoom% become live
/// once the canvas (step 4+) and selection model (step 7+) exist; shown as
/// honest placeholders (not fabricated numbers) until then.
struct StatusBarView: View {
    @ObservedObject var document: DiagramDocument

    private var currentPageName: String {
        document.model.pageOrder.first
            .flatMap { document.model.pages[$0] }?
            .name ?? "—"
    }

    var body: some View {
        HStack(spacing: 16) {
            Text(currentPageName)
            Spacer()
            Text("Selection: —")
            Text("Objects: —")
            Text("100%")
                .monospacedDigit()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
