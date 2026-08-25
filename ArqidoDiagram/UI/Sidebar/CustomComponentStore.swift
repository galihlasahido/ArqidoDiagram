import Foundation
import DiagramModel
import DiagramPersistence

/// Thin `ObservableObject` wrapper around `DiagramPersistence.
/// CustomComponentLibrary` — the library itself stays SwiftUI-free (it only
/// needs Foundation file I/O), so the `@Published` boundary lives here at
/// the app-target edge, the same layering `DiagramDocument` uses for
/// `DiagramPersistence.PackageWriter`/`PackageReader`.
final class CustomComponentStore: ObservableObject {
    @Published private(set) var components: [CustomComponent]
    private let library = CustomComponentLibrary()

    init() {
        components = library.components
    }

    func save(_ component: CustomComponent) {
        components = library.save(component)
    }

    func delete(id: CustomComponentID) {
        components = library.delete(id: id)
    }
}
