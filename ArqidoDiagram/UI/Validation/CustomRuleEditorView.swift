import SwiftUI
import DiagramValidation

/// "Allow custom rules later" from the spec — one rule shape (see
/// `CustomRule`'s doc comment) covers most real architecture rules without
/// needing a general expression language, so this form stays a handful of
/// plain fields rather than a rule-builder UI.
struct CustomRuleEditorView: View {
    @ObservedObject var store: ValidationStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var subjectType = ""
    @State private var relatedType = ""
    @State private var requireRelated = true
    @State private var severity: ValidationSeverity = .warning

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Custom Validation Rules")
                .font(.headline)

            if store.customRules.isEmpty {
                Text("No custom rules yet.")
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(store.customRules) { rule in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rule.name).font(.callout)
                            Text(ruleSummary(rule))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { indices in
                        for index in indices { store.delete(id: store.customRules[index].id) }
                    }
                }
                .frame(height: 140)
            }

            Divider()

            Form {
                TextField("Rule Name", text: $name)
                TextField("Subject Type (e.g. database)", text: $subjectType)
                Picker("Condition", selection: $requireRelated) {
                    Text("Must connect to").tag(true)
                    Text("Must not connect to").tag(false)
                }
                .pickerStyle(.segmented)
                TextField("Related Type (e.g. firewall)", text: $relatedType)
                Picker("Severity", selection: $severity) {
                    Text("Error").tag(ValidationSeverity.error)
                    Text("Warning").tag(ValidationSeverity.warning)
                    Text("Information").tag(ValidationSeverity.information)
                }
            }

            HStack {
                Spacer()
                Button("Close") { dismiss() }
                Button("Add Rule") { addRule() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty
                        || subjectType.trimmingCharacters(in: .whitespaces).isEmpty
                        || relatedType.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func ruleSummary(_ rule: CustomRule) -> String {
        let relation = rule.requireRelated ? "must connect to" : "must not connect to"
        return "\"\(rule.subjectType)\" \(relation) \"\(rule.relatedType)\" — \(rule.severity.rawValue.capitalized)"
    }

    private func addRule() {
        let rule = CustomRule(
            name: name.trimmingCharacters(in: .whitespaces),
            subjectType: subjectType.trimmingCharacters(in: .whitespaces),
            relatedType: relatedType.trimmingCharacters(in: .whitespaces),
            requireRelated: requireRelated,
            severity: severity,
            message: ""
        )
        store.save(rule)
        name = ""
        subjectType = ""
        relatedType = ""
    }
}
