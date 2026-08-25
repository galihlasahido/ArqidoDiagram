import DiagramModel

/// Places every node on a uniform grid sized to the largest node plus a
/// fixed margin, in the page's existing z-order — a stable, deterministic
/// order, so re-running the layout on an already-tidy diagram doesn't
/// reshuffle it.
public struct GridLayoutEngine: LayoutEngine {
    public let displayName = "Grid"
    private let margin: Double

    public init(margin: Double = 40) {
        self.margin = margin
    }

    public func layout(_ page: DiagramPage) -> DiagramPage {
        var result = page
        let nodes = LayoutSupport.orderedNodes(page)
        guard !nodes.isEmpty else { return result }

        let cellWidth = (nodes.map(\.size.width).max() ?? 160) + margin
        let cellHeight = (nodes.map(\.size.height).max() ?? 100) + margin
        let columns = max(1, Int(Double(nodes.count).squareRoot().rounded(.up)))

        for (index, node) in nodes.enumerated() {
            let column = index % columns
            let row = index / columns
            var updated = node
            updated.position = Point2D(x: Double(column) * cellWidth, y: Double(row) * cellHeight)
            result.nodes[node.id] = updated
        }
        return result
    }
}
