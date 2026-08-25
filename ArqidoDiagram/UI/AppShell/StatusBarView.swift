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
    @ObservedObject var connectorStyle: ConnectorStyleModel
    @Binding var activePageID: PageID?

    private var objectCount: Int {
        guard let id = activePageID ?? document.model.pageOrder.first else { return 0 }
        return document.model.pages[id]?.nodes.count ?? 0
    }

    var body: some View {
        HStack(spacing: 16) {
            PageTabsView(document: document, activePageID: $activePageID)
            Spacer()
            connectorStylePicker
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

    /// Sets which `RoutingStyle` the drag-to-connect tool draws *new*
    /// connectors with (`DiagramCanvasView.defaultRoutingStyle`) — to
    /// change an existing connector's routing instead, select it and use
    /// the Inspector's Connector section.
    private var connectorStylePicker: some View {
        Picker("Line", selection: $connectorStyle.routingStyle) {
            ForEach(RoutingStyle.allCases, id: \.self) { style in
                Text(style.displayName).tag(style)
            }
        }
        .pickerStyle(.menu)
        .fixedSize()
        .help("Line style for new connectors")
    }
}
