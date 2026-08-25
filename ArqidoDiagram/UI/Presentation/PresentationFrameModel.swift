import Foundation

/// Toggled by ⌘⇧P — see `AppCommands` + `.togglePresentationFramePanel`,
/// the same notification-based pattern `ADRModel`/`VersionHistoryModel` use.
final class PresentationFrameModel: ObservableObject {
    @Published var isPresented = false
}

extension Notification.Name {
    static let togglePresentationFramePanel = Notification.Name("ArqidoDiagram.togglePresentationFramePanel")
    static let enterPresentationMode = Notification.Name("ArqidoDiagram.enterPresentationMode")
}
