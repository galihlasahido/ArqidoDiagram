import Foundation

public struct Port: Codable, Hashable, Sendable {
    public var id: PortID
    /// Normalized 0...1 position within the owning node's bounds.
    public var relativePosition: Point2D

    public init(id: PortID = PortID(), relativePosition: Point2D) {
        self.id = id
        self.relativePosition = relativePosition
    }
}

public struct TextContent: Codable, Hashable, Sendable {
    public var string: String

    public init(string: String) {
        self.string = string
    }
}

public struct DiagramNode: Codable, Identifiable, Hashable, Sendable {
    public var id: NodeID
    public var type: ShapeType
    /// Top-left, in page-local coordinates.
    public var position: Point2D
    public var size: Size2D
    /// Radians.
    public var rotation: Double
    public var style: ShapeStyle
    public var text: TextContent?
    public var metadata: Metadata
    public var zIndex: Int
    public var groupID: GroupID?
    public var isLocked: Bool
    public var isHidden: Bool
    /// Reserved for connector attachment points; populated in a later phase.
    public var ports: [Port]
    /// Optional technology/vendor icon badge drawn over the shape (see
    /// `PageRenderer.drawNode`) — independent of `type`, which stays purely
    /// about the outline/silhouette. `Optional` so older documents without
    /// this field decode via `decodeIfPresent` to `nil`, unaffected.
    public var iconType: TechIconType?

    public init(
        id: NodeID = NodeID(),
        type: ShapeType,
        position: Point2D,
        size: Size2D,
        rotation: Double = 0,
        style: ShapeStyle = ShapeStyle(),
        text: TextContent? = nil,
        metadata: Metadata = Metadata(),
        zIndex: Int = 0,
        groupID: GroupID? = nil,
        isLocked: Bool = false,
        isHidden: Bool = false,
        ports: [Port] = [],
        iconType: TechIconType? = nil
    ) {
        self.id = id
        self.type = type
        self.position = position
        self.size = size
        self.rotation = rotation
        self.style = style
        self.text = text
        self.metadata = metadata
        self.zIndex = zIndex
        self.groupID = groupID
        self.isLocked = isLocked
        self.isHidden = isHidden
        self.ports = ports
        self.iconType = iconType
    }
}
