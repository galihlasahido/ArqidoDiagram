import Foundation

/// Toggled by ⌘⇧V (see `AppCommands` + the `.toggleValidation`
/// notification) — same reasoning as `SearchModel`/`.toggleSearch`: menu
/// Commands are constructed once at the app level, disconnected from any
/// specific window's SwiftUI state.
final class ValidationModel: ObservableObject {
    @Published var isPresented = false
}

extension Notification.Name {
    static let toggleValidation = Notification.Name("ArqidoDiagram.toggleValidation")
}
