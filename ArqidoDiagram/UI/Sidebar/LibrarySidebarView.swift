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
    @ObservedObject var componentStore: CustomComponentStore

    @State private var searchText = ""
    @State private var favorites: Set<ShapeType> = []
    @State private var recentlyUsed: [ShapeType] = []

    private var searchResults: [ShapeCatalogEntry]? {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }
        let lowered = query.lowercased()
        return ShapeCatalog.all.filter { $0.name.lowercased().contains(lowered) }
    }

    private var iconSearchResults: [TechIconCatalogEntry]? {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }
        let lowered = query.lowercased()
        return TechIconCatalog.all.filter {
            $0.name.lowercased().contains(lowered) || $0.tags.contains { $0.lowercased().contains(lowered) }
        }
    }

    private var componentSearchResults: [CustomComponent]? {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }
        let lowered = query.lowercased()
        return componentStore.components.filter {
            $0.name.lowercased().contains(lowered) || $0.category.lowercased().contains(lowered)
        }
    }

    private var componentsByCategory: [(category: String, components: [CustomComponent])] {
        let grouped = Dictionary(grouping: componentStore.components, by: \.category)
        return grouped.keys.sorted().map { (category: $0, components: grouped[$0] ?? []) }
    }

    var body: some View {
        List {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search shapes…", text: $searchText)
                    .textFieldStyle(.plain)
            }

            if searchResults != nil || iconSearchResults != nil || componentSearchResults != nil {
                Section("Results") {
                    ForEach(searchResults ?? []) { entry in shapeRow(entry) }
                    ForEach(iconSearchResults ?? []) { entry in iconRow(entry) }
                    ForEach(componentSearchResults ?? []) { component in componentRow(component) }
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
                if !componentStore.components.isEmpty {
                    ForEach(componentsByCategory, id: \.category) { group in
                        Section("My Components — \(group.category)") {
                            ForEach(group.components) { component in componentRow(component) }
                        }
                    }
                }
                ForEach(ShapeCategory.allCases, id: \.self) { category in
                    Section(category.rawValue) {
                        ForEach(ShapeCatalog.entries(for: category)) { entry in shapeRow(entry) }
                    }
                }
                ForEach(IconPack.allCases, id: \.self) { pack in
                    Section("\(pack.rawValue) Icons") {
                        ForEach(TechIconCatalog.entries(for: pack)) { entry in iconRow(entry) }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Libraries")
    }

    private var recentEntries: [ShapeCatalogEntry] {
        // `ShapeCatalog.all` deliberately lists some shapes (networkFirewall,
        // networkVPN) under two categories, so `.type` isn't a unique key —
        // `uniquingKeysWith` keeps whichever entry appears first rather than
        // crashing on the duplicate.
        let byType = Dictionary(ShapeCatalog.all.map { ($0.type, $0) }, uniquingKeysWith: { first, _ in first })
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
        shapeInsertion.pending = PendingInsertion(shapeType: entry.type)
        recentlyUsed.removeAll { $0 == entry.type }
        recentlyUsed.insert(entry.type, at: 0)
        if recentlyUsed.count > 8 { recentlyUsed.removeLast() }
    }

    private func toggleFavorite(_ type: ShapeType) {
        if favorites.contains(type) { favorites.remove(type) } else { favorites.insert(type) }
    }

    /// Icon badges are inserted as a rounded-rectangle "container" node
    /// carrying the icon type and a name label — a real, editable node
    /// (movable/resizable/re-stylable like any other), not a special-cased
    /// read-only pictogram.
    private func iconRow(_ entry: TechIconCatalogEntry) -> some View {
        Button {
            shapeInsertion.pending = PendingInsertion(shapeType: .roundedRectangle, iconType: entry.id, text: entry.name)
        } label: {
            Label(entry.name, systemImage: "square.grid.2x2")
        }
        .buttonStyle(.plain)
        .help("Add \(entry.pack.rawValue) \(entry.name) to the canvas")
    }

    private func componentRow(_ component: CustomComponent) -> some View {
        HStack {
            Button {
                shapeInsertion.pendingComponent = component
            } label: {
                Label(component.name, systemImage: "square.on.square")
            }
            .buttonStyle(.plain)
            .help("Add \(component.name) to the canvas")

            Spacer()

            Button {
                componentStore.delete(id: component.id)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete \(component.name) from My Components")
        }
    }
}
