import Foundation

public enum EndpointRef: Codable, Hashable, Sendable {
    case node(NodeID, portID: PortID?)
    case point(Point2D)
}

public enum RoutingStyle: String, Codable, Sendable {
    case straight, orthogonal, curved
}

public struct EdgeLabel: Codable, Hashable, Sendable {
    public var text: String
    /// 0...1 position along the routed path.
    public var position: Double

    public init(text: String, position: Double = 0.5) {
        self.text = text
        self.position = position
    }
}

public struct DiagramEdge: Codable, Identifiable, Sendable {
    public var id: EdgeID
    public var source: EndpointRef
    public var target: EndpointRef
    public var routing: RoutingStyle
    /// User-adjusted bend points, in page-local coordinates.
    public var waypoints: [Point2D]
    public var style: LineStyle
    public var labels: [EdgeLabel]
    public var zIndex: Int
    public var isLocked: Bool
    public var isHidden: Bool

    public init(
        id: EdgeID = EdgeID(),
        source: EndpointRef,
        target: EndpointRef,
        routing: RoutingStyle = .straight,
        waypoints: [Point2D] = [],
        style: LineStyle = LineStyle(),
        labels: [EdgeLabel] = [],
        zIndex: Int = 0,
        isLocked: Bool = false,
        isHidden: Bool = false
    ) {
        self.id = id
        self.source = source
        self.target = target
        self.routing = routing
        self.waypoints = waypoints
        self.style = style
        self.labels = labels
        self.zIndex = zIndex
        self.isLocked = isLocked
        self.isHidden = isHidden
    }
}
