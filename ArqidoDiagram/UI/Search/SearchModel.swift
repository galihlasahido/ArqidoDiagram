import Foundation

/// Toggled by ⌘F (see `AppCommands` + the `.toggleSearch` notification —
/// menu Commands are constructed once at the app level, disconnected from
/// any specific window's SwiftUI state, so a notification is how the
/// keyboard shortcut reaches whichever window's `ContentView` is frontmost).
final class SearchModel: ObservableObject {
    @Published var isPresented = false
    @Published var query = ""
}

extension Notification.Name {
    static let toggleSearch = Notification.Name("ArqidoDiagram.toggleSearch")
}
