import SwiftUI
import DiagramModel

/// Every Phase 1+2 shape (General/Flowchart/UML/C4/ERD/BPMN/Network/
/// Security) via `ShapeCatalog`, with search/favorites/recently-used —
/// per the spec's Shape Palette requirements. Clicking a shape adds it to
/// the canvas (via `ShapeInsertionRequest` -> `CanvasHostView`) at the
/// current viewport center; drag-and-drop onto a specific drop point is a
/// reasonable future refinement, not required for "Add shapes" to be
/// genuinely real today. Favorites/recents are session-only (not persisted
/// across launches) — a deliberate scope cut, not an oversight.
struct LibrarySidebarView: View {
    @ObservedObject var shapeInsertion: ShapeInsertionRequest

    @State private var searchText = ""
    @State private var favorites: Set<ShapeType> = []
    @State private var recentlyUsed: [ShapeType] = []

    private var searchResults: [ShapeCatalogEntry]? {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }
        let lowered = query.lowercased()
        return ShapeCatalog.all.filter { $0.name.lowercased().contains(lowered) }
    }

    var body: some View {
        List {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search shapes…", text: $searchText)
                    .textFieldStyle(.plain)
            }

            if let results = searchResults {
                Section("Results") {
                    ForEach(results) { entry in shapeRow(entry) }
                }
            } else {
                if !favorites.isEmpty {
                    Section("Favorites") {
                        ForEach(ShapeCatalog.all.filter { favorites.contains($0.type) }) { entry in shapeRow(entry) }
                    }
                }
                if !recentlyUsed.isEmpty {
                    Section("Recently Used") {
                        ForEach(recentEntries) { entry in shapeRow(entry) }
                    }
                }
                ForEach(ShapeCategory.allCases, id: \.self) { category in
                    Section(category.rawValue) {
                        ForEach(ShapeCatalog.entries(for: category)) { entry in shapeRow(entry) }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Libraries")
    }

    private var recentEntries: [ShapeCatalogEntry] {
        let byType = Dictionary(uniqueKeysWithValues: ShapeCatalog.all.map { ($0.type, $0) })
        return recentlyUsed.compactMap { byType[$0] }
    }

    private func shapeRow(_ entry: ShapeCatalogEntry) -> some View {
        HStack {
            Button {
                insert(entry)
            } label: {
                Label(entry.name, systemImage: entry.symbol)
            }
            .buttonStyle(.plain)
            .help("Add \(entry.name) to the canvas")

            Spacer()

            Button {
                toggleFavorite(entry.type)
            } label: {
                Image(systemName: favorites.contains(entry.type) ? "star.fill" : "star")
                    .foregroundStyle(favorites.contains(entry.type) ? Color.yellow : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(favorites.contains(entry.type) ? "Remove from Favorites" : "Add to Favorites")
        }
    }

    private func insert(_ entry: ShapeCatalogEntry) {
        shapeInsertion.pendingType = entry.type
        recentlyUsed.removeAll { $0 == entry.type }
        recentlyUsed.insert(entry.type, at: 0)
        if recentlyUsed.count > 8 { recentlyUsed.removeLast() }
    }

    private func toggleFavorite(_ type: ShapeType) {
        if favorites.contains(type) { favorites.remove(type) } else { favorites.insert(type) }
    }
}
