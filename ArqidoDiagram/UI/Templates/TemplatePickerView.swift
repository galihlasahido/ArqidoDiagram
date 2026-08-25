import SwiftUI
import DiagramModel

/// "File > New from Template…" — a flat, categorized list rather than a
/// visual gallery of thumbnails: consistent with the app's no-custom-
/// design-system rule (plain `List`/`Form`, system-dynamic colors), and a
/// gallery would need rendered previews of every template just to exist.
struct TemplatePickerView: View {
    let onSelect: (DiagramTemplate) -> Void
    let onCancel: () -> Void

    @State private var selection: DiagramTemplate.ID?

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(TemplateCategory.allCases, id: \.self) { category in
                    Section(category.rawValue) {
                        ForEach(TemplateCatalog.entries(for: category)) { template in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(template.name).font(.callout)
                                Text(template.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(template.id)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 380, minHeight: 420)

            Divider()

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Create") {
                    guard let template = TemplateCatalog.all.first(where: { $0.id == selection }) else { return }
                    onSelect(template)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selection == nil)
            }
            .padding(12)
        }
    }
}
