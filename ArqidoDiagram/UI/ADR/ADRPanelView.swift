import SwiftUI
import DiagramModel

/// Lists a document's ADRs newest-first-by-number, each showing its
/// status; tapping one opens `ADREditorView` for editing (including
/// relinking objects), and "New ADR" opens the same editor blank.
struct ADRPanelView: View {
    @ObservedObject var document: DiagramDocument
    @ObservedObject var adrModel: ADRModel
    @ObservedObject var selection: SelectionModel

    @State private var editingADR: ArchitectureDecisionRecord?
    @State private var showingNewADR = false

    private var sortedADRs: [ArchitectureDecisionRecord] {
        document.adrs.sorted { $0.number > $1.number }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if sortedADRs.isEmpty {
                Text("No ADRs yet. Record architecture decisions and link them to the objects they affect.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                list
            }
            Divider()
            HStack {
                Spacer()
                Button("New ADR…") { showingNewADR = true }
                    .padding(8)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor)))
        .shadow(radius: 8)
        .frame(width: 420)
        .sheet(item: $editingADR) { adr in
            ADREditorView(document: document, selection: selection, existing: adr) { editingADR = nil }
        }
        .sheet(isPresented: $showingNewADR) {
            ADREditorView(document: document, selection: selection, existing: nil) { showingNewADR = false }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "doc.text.magnifyingglass")
                .foregroundStyle(.secondary)
            Text("Architecture Decision Records")
                .font(.callout.weight(.semibold))
            Spacer()
            Text("\(sortedADRs.count)")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Button {
                adrModel.isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(8)
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(sortedADRs) { adr in
                    Button {
                        editingADR = adr
                    } label: {
                        row(adr)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
        .frame(maxHeight: 360)
    }

    private func row(_ adr: ArchitectureDecisionRecord) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("ADR-\(String(format: "%03d", adr.number)): \(adr.title)")
                    .font(.callout)
                if !adr.linkedNodeIDs.isEmpty {
                    Text("Linked to \(adr.linkedNodeIDs.count) object(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            statusBadge(adr.status)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func statusBadge(_ status: ADRStatus) -> some View {
        let color: Color = switch status {
        case .accepted: .green
        case .rejected: .red
        case .deprecated, .superseded: .gray
        case .proposed: .yellow
        }
        return Text(status.displayName)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
    }
}
