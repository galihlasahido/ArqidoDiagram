import Foundation
import DiagramModel

/// Which `RoutingStyle` the interactive drag-to-connect tool draws new
/// connectors with (see `DiagramCanvasView.defaultRoutingStyle`) — small,
/// session-local UI state, not part of the persisted document. Existing
/// edges keep whatever routing they were created with; changing this only
/// affects connectors drawn afterward (to re-route an existing edge, select
/// it and use the Inspector's Connector section instead).
final class ConnectorStyleModel: ObservableObject {
    @Published var routingStyle: RoutingStyle = .straight
}
