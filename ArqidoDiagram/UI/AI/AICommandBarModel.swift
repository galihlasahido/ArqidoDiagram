import Foundation

/// Toggled by ⌘K — see `AppCommands` + `.toggleAICommandBar`, the same
/// notification-based pattern `SearchModel`/`ValidationModel` use since
/// menu Commands are constructed once at the app level.
final class AICommandBarModel: ObservableObject {
    @Published var isPresented = false
}

extension Notification.Name {
    static let toggleAICommandBar = Notification.Name("ArqidoDiagram.toggleAICommandBar")
}
