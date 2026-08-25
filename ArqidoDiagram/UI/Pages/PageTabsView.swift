import SwiftUI
import DiagramModel

/// The bottom-bar page strip per the spec's UI layout ("Page 1  Page 2
/// Page 3 ... 100%  +"). Reordering pages by drag isn't implemented — a
/// scoped Phase 1 cut; add/rename/delete/duplicate/switch are all real.
struct PageTabsView: View {
    @ObservedObject var document: DiagramDocument
    @Binding var activePageID: PageID?

    @State private var renamingPageID: PageID?
    @State private var renameText: String = ""

    var body: some View {
        HStack(spacing: 2) {
            ForEach(document.model.pageOrder, id: \.self) { id in
                if let page = document.model.pages[id] {
                    tab(id: id, page: page)
                }
            }
            Button {
                let newID = document.addPage()
                activePageID = newID
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.plain)
            .help("Add Page")
            .padding(.leading, 4)
        }
        .alert("Rename Page", isPresented: renamingBinding) {
            TextField("Name", text: $renameText)
            Button("Rename") {
                if let id = renamingPageID { document.renamePage(id: id, to: renameText) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var renamingBinding: Binding<Bool> {
        Binding(get: { renamingPageID != nil }, set: { if !$0 { renamingPageID = nil } })
    }

    private func tab(id: PageID, page: DiagramPage) -> some View {
        let isActive = activePageID == id
        return Button {
            activePageID = id
        } label: {
            Text(page.name)
                .fontWeight(isActive ? .semibold : .regular)
                .foregroundStyle(isActive ? Color.primary : Color.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(isActive ? Color(nsColor: .selectedControlColor).opacity(0.3) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Rename…") {
                renameText = page.name
                renamingPageID = id
            }
            Button("Duplicate") {
                document.duplicatePage(id: id)
            }
            Divider()
            Button("Delete", role: .destructive) {
                deletePage(id)
            }
            .disabled(document.model.pageOrder.count <= 1)
        }
    }

    private func deletePage(_ id: PageID) {
        let wasActive = activePageID == id
        document.removePage(id: id)
        if wasActive {
            activePageID = document.model.pageOrder.first
        }
    }
}
