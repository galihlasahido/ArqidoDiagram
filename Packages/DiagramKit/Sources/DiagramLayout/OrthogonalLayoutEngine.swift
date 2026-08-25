import DiagramModel

/// A grid placement plus switching every edge to orthogonal routing — node
/// position alone doesn't make a diagram read as "orthogonal", the edges
/// have to bend at right angles too, so this composes `GridLayoutEngine`
/// with an edge-routing pass rather than duplicating the grid math.
public struct OrthogonalLayoutEngine: LayoutEngine {
    public let displayName = "Orthogonal"
    private let grid = GridLayoutEngine()

    public init() {}

    public func layout(_ page: DiagramPage) -> DiagramPage {
        var result = grid.layout(page)
        for (id, edge) in result.edges {
            var updated = edge
            updated.routing = .orthogonal
            result.edges[id] = updated
        }
        return result
    }
}
