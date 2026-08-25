import SwiftUI
import DiagramModel

/// Create/edit form for one ADR — matches the spec's own worked example
/// fields exactly (Title/Status/Context/Decision/Consequences), plus a
/// "Link Selected Objects" button for the spec's "ADRs should link to
/// diagram objects" requirement.
struct ADREditorView: View {
    @ObservedObject var document: DiagramDocument
    @ObservedObject var selection: SelectionModel
    /// `nil` means "creating a new ADR".
    let existing: ArchitectureDecisionRecord?
    let onDismiss: () -> Void

    @State private var title: String
    @State private var status: ADRStatus
    @State private var context: String
    @State private var decision: String
    @State private var consequencesText: String
    @State private var linkedNodeIDs: [NodeID]

    init(document: DiagramDocument, selection: SelectionModel, existing: ArchitectureDecisionRecord?, onDismiss: @escaping () -> Void) {
        self.document = document
        self.selection = selection
        self.existing = existing
        self.onDismiss = onDismiss
        _title = State(initialValue: existing?.title ?? "")
        _status = State(initialValue: existing?.status ?? .proposed)
        _context = State(initialValue: existing?.context ?? "")
        _decision = State(initialValue: existing?.decision ?? "")
        _consequencesText = State(initialValue: (existing?.consequences ?? []).joined(separator: "\n"))
        _linkedNodeIDs = State(initialValue: existing?.linkedNodeIDs ?? [])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(existing == nil ? "New ADR" : "Edit ADR-\(String(format: "%03d", existing!.number))")
                .font(.headline)

            Form {
                TextField("Title", text: $title)
                Picker("Status", selection: $status) {
                    ForEach(ADRStatus.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Section("Context") {
                    TextEditor(text: $context).frame(height: 60)
                }
                Section("Decision") {
                    TextEditor(text: $decision).frame(height: 60)
                }
                Section("Consequences (one per line, e.g. \"+ High throughput\")") {
                    TextEditor(text: $consequencesText).frame(height: 60)
                }
            }

            HStack {
                Button {
                    linkedNodeIDs = Array(selection.selectedNodeIDs)
                } label: {
                    Label("Link \(selection.selectedNodeIDs.count) Selected Object(s)", systemImage: "link")
                }
                .disabled(selection.selectedNodeIDs.isEmpty)
                Spacer()
                Text("\(linkedNodeIDs.count) object(s) linked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                if existing != nil {
                    Button("Delete", role: .destructive) {
                        document.deleteADR(id: existing!.id)
                        onDismiss()
                    }
                }
                Spacer()
                Button("Cancel") { onDismiss() }
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private func save() {
        let consequences = consequencesText
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if let existing {
            var updated = existing
            updated.title = title
            updated.status = status
            updated.context = context
            updated.decision = decision
            updated.consequences = consequences
            updated.linkedNodeIDs = linkedNodeIDs
            document.updateADR(updated)
        } else {
            let created = document.addADR(title: title, status: status, context: context, decision: decision, consequences: consequences)
            document.setLinkedNodes(linkedNodeIDs, forADRWithID: created.id)
        }
        onDismiss()
    }
}
