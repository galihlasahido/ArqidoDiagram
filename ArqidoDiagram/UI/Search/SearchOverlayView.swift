import SwiftUI
import DiagramModel

/// Searches object text/metadata/tags and page names across every page
/// (per the spec's "Search: Object name, Metadata, Technology, Owner,
/// Environment, Tags, Page" list) — not just the active page. Selecting a
/// result switches to its page (if needed) and zooms to it.
struct SearchOverlayView: View {
    @ObservedObject var document: DiagramDocument
    @ObservedObject var searchModel: SearchModel
    @ObservedObject var bridge: InspectorBridge
    @Binding var activePageID: PageID?

    private struct Result: Identifiable {
        let nodeID: NodeID
        let pageID: PageID
        let pageName: String
        let label: String
        let matchDetail: String
        var id: NodeID { nodeID }
    }

    private var results: [Result] {
        let query = searchModel.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let lowered = query.lowercased()

        var found: [Result] = []
        for pageID in document.model.pageOrder {
            guard let page = document.model.pages[pageID] else { continue }
            for node in page.nodes.values.sorted(by: { $0.zIndex < $1.zIndex }) {
                guard let detail = matchDetail(for: node, page: page, query: lowered) else { continue }
                found.append(Result(
                    nodeID: node.id,
                    pageID: pageID,
                    pageName: page.name,
                    label: node.text?.string ?? node.type.rawValue.capitalized,
                    matchDetail: detail
                ))
            }
        }
        return found
    }

    private func matchDetail(for node: DiagramNode, page: DiagramPage, query: String) -> String? {
        if let text = node.text?.string, text.lowercased().contains(query) { return text }
        if let value = node.metadata.semanticType, value.lowercased().contains(query) { return "Type: \(value)" }
        if let value = node.metadata.technology, value.lowercased().contains(query) { return "Technology: \(value)" }
        if let value = node.metadata.owner, value.lowercased().contains(query) { return "Owner: \(value)" }
        if let value = node.metadata.environment, value.lowercased().contains(query) { return "Environment: \(value)" }
        if let value = node.metadata.criticality, value.lowercased().contains(query) { return "Criticality: \(value)" }
        if let tag = node.metadata.tags.first(where: { $0.lowercased().contains(query) }) { return "Tag: \(tag)" }
        if page.name.lowercased().contains(query) { return "Page: \(page.name)" }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search objects, metadata, pages…", text: $searchModel.query)
                    .textFieldStyle(.plain)
                    .onSubmit { selectFirstResult() }
                Text("\(results.count)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Button {
                    searchModel.isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(8)

            if !results.isEmpty {
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(results.prefix(20)) { result in
                            resultRow(result)
                        }
                    }
                }
                .frame(maxHeight: 240)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor)))
        .shadow(radius: 8)
        .frame(width: 360)
    }

    private func resultRow(_ result: Result) -> some View {
        Button {
            select(result)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(result.label).font(.callout)
                Text("\(result.pageName) — \(result.matchDetail)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func selectFirstResult() {
        guard let first = results.first else { return }
        select(first)
    }

    private func select(_ result: Result) {
        activePageID = result.pageID
        searchModel.isPresented = false
        // Deferred: switching pages updates SwiftUI state that reaches the
        // NSView on the next run loop turn (via CanvasHostView.updateNSView),
        // not synchronously — zoomToNode needs that page already loaded.
        DispatchQueue.main.async {
            bridge.canvasView?.zoomToNode(result.nodeID)
        }
    }
}
