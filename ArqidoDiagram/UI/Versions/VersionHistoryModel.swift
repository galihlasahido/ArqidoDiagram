import Foundation

/// Toggled by ⌘⇧H (see `AppCommands` + the `.toggleVersionHistory`
/// notification) — same reasoning as `SearchModel`/`ValidationModel`: menu
/// Commands are constructed once at the app level, disconnected from any
/// specific window's SwiftUI state.
final class VersionHistoryModel: ObservableObject {
    @Published var isPresented = false
}

extension Notification.Name {
    static let toggleVersionHistory = Notification.Name("ArqidoDiagram.toggleVersionHistory")
}
