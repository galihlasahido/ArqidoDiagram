import SwiftUI
import DiagramModel
import DiagramValidation

/// Runs `ValidationEngine` (built-in rules + whatever custom rules are
/// saved) across every page — an architecture can legitimately span
/// several pages/views, so a violation on a page the user isn't currently
/// looking at still needs to surface. Selecting a finding switches to its
/// page and selects/zooms to the offending node(s), the same interaction
/// `SearchOverlayView` uses for its results.
struct ValidationPanelView: View {
    @ObservedObject var document: DiagramDocument
    @ObservedObject var validationModel: ValidationModel
    @ObservedObject var store: ValidationStore
    @ObservedObject var bridge: InspectorBridge
    @Binding var activePageID: PageID?

    @State private var showingRuleEditor = false

    private struct PageIssue: Identifiable {
        let issue: ValidationIssue
        let pageID: PageID
        let pageName: String
        var id: UUID { issue.id }
    }

    private var allIssues: [PageIssue] {
        var result: [PageIssue] = []
        for pageID in document.model.pageOrder {
            guard let page = document.model.pages[pageID] else { continue }
            for issue in store.issues(for: page) {
                result.append(PageIssue(issue: issue, pageID: pageID, pageName: page.name))
            }
        }
        result.sort { lhs, rhs in
            if lhs.issue.severity != rhs.issue.severity { return lhs.issue.severity > rhs.issue.severity }
            return lhs.issue.message < rhs.issue.message
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if allIssues.isEmpty {
                emptyState
            } else {
                issueList
            }
            Divider()
            footer
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor)))
        .shadow(radius: 8)
        .frame(width: 420)
        .sheet(isPresented: $showingRuleEditor) {
            CustomRuleEditorView(store: store)
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "checkmark.shield")
                .foregroundStyle(.secondary)
            Text("Architecture Validation")
                .font(.callout.weight(.semibold))
            Spacer()
            Text("\(allIssues.count)")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Button {
                validationModel.isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(8)
    }

    private var emptyState: some View {
        Text("No issues found across \(document.model.pageOrder.count) page(s).")
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding()
    }

    private var issueList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(allIssues) { pageIssue in
                    issueRow(pageIssue)
                    Divider()
                }
            }
        }
        .frame(maxHeight: 320)
    }

    private func issueRow(_ pageIssue: PageIssue) -> some View {
        Button {
            select(pageIssue)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                severityIcon(pageIssue.issue.severity)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pageIssue.issue.message)
                        .font(.callout)
                        .multilineTextAlignment(.leading)
                    Text("\(pageIssue.issue.ruleName) — \(pageIssue.pageName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func severityIcon(_ severity: ValidationSeverity) -> some View {
        let (symbol, color): (String, Color) = switch severity {
        case .error: ("xmark.octagon.fill", .red)
        case .warning: ("exclamationmark.triangle.fill", .yellow)
        case .information: ("info.circle.fill", .blue)
        }
        return Image(systemName: symbol).foregroundStyle(color)
    }

    private var footer: some View {
        HStack {
            Text("\(store.customRules.count) custom rule(s)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Manage Custom Rules…") {
                showingRuleEditor = true
            }
            .buttonStyle(.link)
        }
        .padding(8)
    }

    private func select(_ pageIssue: PageIssue) {
        activePageID = pageIssue.pageID
        DispatchQueue.main.async {
            guard let firstNodeID = pageIssue.issue.nodeIDs.first else { return }
            bridge.canvasView?.zoomToNode(firstNodeID)
            bridge.canvasView?.applyExternalSelection(Set(pageIssue.issue.nodeIDs))
        }
    }
}
