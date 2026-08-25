import Foundation

/// Toggled by ⌘⇧R — see `AppCommands` + `.toggleADRPanel`, the same
/// notification-based pattern `VersionHistoryModel`/`ValidationModel` use.
final class ADRModel: ObservableObject {
    @Published var isPresented = false
}

extension Notification.Name {
    static let toggleADRPanel = Notification.Name("ArqidoDiagram.toggleADRPanel")
}
