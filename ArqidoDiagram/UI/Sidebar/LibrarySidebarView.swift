import SwiftUI

/// Phase 1 scope only: General + Flowchart. UML/C4/ERD/BPMN/Network/
/// Security/cloud-vendor libraries are later phases. Drag-and-drop onto the
/// canvas lands once the canvas (step 4+) and interaction layer (step 6+)
/// exist — this is a real, if not yet interactive, category list, not a
/// fabricated one.
struct LibrarySidebarView: View {
    private let categories = ["General", "Flowchart"]

    var body: some View {
        List {
            Section("Libraries") {
                ForEach(categories, id: \.self) { category in
                    Label(category, systemImage: "square.grid.2x2")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Libraries")
    }
}
