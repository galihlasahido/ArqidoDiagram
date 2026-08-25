import Foundation
import DiagramModel

/// Places every node evenly spaced around a circle. Radius is derived from
/// node count and average node diagonal so evenly-spaced nodes don't
/// overlap, rather than a fixed radius that only looks right for one
/// particular node count.
public struct CircularLayoutEngine: LayoutEngine {
    public let displayName = "Circular"

    public init() {}

    public func layout(_ page: DiagramPage) -> DiagramPage {
        var result = page
        let nodes = LayoutSupport.orderedNodes(page)
        guard !nodes.isEmpty else { return result }
        guard nodes.count > 1 else {
            var updated = nodes[0]
            updated.position = Point2D(x: 0, y: 0)
            result.nodes[updated.id] = updated
            return result
        }

        let averageDiagonal = nodes
            .map { (($0.size.width * $0.size.width) + ($0.size.height * $0.size.height)).squareRoot() }
            .reduce(0, +) / Double(nodes.count)
        let circumference = averageDiagonal * Double(nodes.count) * 1.4
        let radius = max(circumference / (2 * Double.pi), averageDiagonal)

        for (index, node) in nodes.enumerated() {
            let angle = 2 * Double.pi * Double(index) / Double(nodes.count) - .pi / 2
            var updated = node
            let centerX = radius * cos(angle)
            let centerY = radius * sin(angle)
            updated.position = Point2D(x: centerX - node.size.width / 2, y: centerY - node.size.height / 2)
            result.nodes[node.id] = updated
        }
        return result
    }
}
