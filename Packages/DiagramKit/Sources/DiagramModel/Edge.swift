import Foundation

public enum EndpointRef: Codable, Hashable, Sendable {
    case node(NodeID, portID: PortID?)
    case point(Point2D)
}

public enum RoutingStyle: String, Codable, Sendable, CaseIterable {
    case straight, orthogonal, curved
    /// Two segments, each following one of the two 2:1-pixel-ratio
    /// isometric grid axes — the diagonal "pseudo-3D" connector look other
    /// diagramming apps offer alongside orthogonal/curved.
    case isometric
    /// The classic ER-diagram "S"/"Z" stepped connector: exits the source
    /// horizontally, jogs vertically at the horizontal midpoint, then
    /// enters the target horizontally — distinct from `.orthogonal`'s
    /// single right-angle bend.
    case entityRelation

    public var displayName: String {
        switch self {
        case .straight: return "Straight"
        case .orthogonal: return "Orthogonal"
        case .curved: return "Curved"
        case .isometric: return "Isometric"
        case .entityRelation: return "Entity Relation"
        }
    }
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

public struct DiagramEdge: Codable, Identifiable, Hashable, Sendable {
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
