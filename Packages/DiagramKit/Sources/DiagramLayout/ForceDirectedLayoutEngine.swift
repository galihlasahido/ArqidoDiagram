import DiagramModel

/// A Fruchterman-Reingold-style force simulation: every pair of nodes
/// repels, connected nodes attract toward an ideal edge length, and the
/// whole system cools linearly over a fixed number of iterations so it
/// settles instead of oscillating forever. Positions are seeded from each
/// node's *current* center (not randomized), so re-running the layout on an
/// already-decent diagram nudges it toward better spacing rather than
/// reshuffling everything.
public struct ForceDirectedLayoutEngine: LayoutEngine {
    public let displayName = "Force-Directed"
    private let iterations: Int
    private let idealEdgeLength: Double

    public init(iterations: Int = 300, idealEdgeLength: Double = 220) {
        self.iterations = iterations
        self.idealEdgeLength = idealEdgeLength
    }

    public func layout(_ page: DiagramPage) -> DiagramPage {
        var result = page
        let nodes = LayoutSupport.orderedNodes(page)
        guard nodes.count > 1 else { return result }

        let ids = nodes.map(\.id)
        var position: [NodeID: (x: Double, y: Double)] = Dictionary(uniqueKeysWithValues: nodes.map {
            ($0.id, ($0.position.x + $0.size.width / 2, $0.position.y + $0.size.height / 2))
        })
        let edgePairs: [(NodeID, NodeID)] = page.edges.values.compactMap { edge in
            guard case .node(let sourceID, _) = edge.source, case .node(let targetID, _) = edge.target, sourceID != targetID else { return nil }
            return (sourceID, targetID)
        }

        let area = Double(nodes.count) * idealEdgeLength * idealEdgeLength
        let k = (area / Double(max(nodes.count, 1))).squareRoot()

        for iteration in 0..<iterations {
            var displacement: [NodeID: (x: Double, y: Double)] = Dictionary(uniqueKeysWithValues: ids.map { ($0, (0.0, 0.0)) })

            for i in 0..<ids.count {
                for j in (i + 1)..<ids.count {
                    let a = ids[i], b = ids[j]
                    guard let pa = position[a], let pb = position[b] else { continue }
                    let rawDx = pa.x - pb.x
                    let rawDy = pa.y - pb.y
                    let rawDistance = (rawDx * rawDx + rawDy * rawDy).squareRoot()
                    // Coincident nodes have no well-defined repulsion
                    // direction — nudge deterministically by index instead
                    // of leaving them stacked forever.
                    let (dx, dy, distance): (Double, Double, Double) = rawDistance < 0.01
                        ? (Double(i - j), Double(j - i), 0.01)
                        : (rawDx, rawDy, rawDistance)
                    let repulsion = (k * k) / distance
                    let fx = (dx / distance) * repulsion
                    let fy = (dy / distance) * repulsion
                    displacement[a]?.x += fx
                    displacement[a]?.y += fy
                    displacement[b]?.x -= fx
                    displacement[b]?.y -= fy
                }
            }

            for (source, target) in edgePairs {
                guard let ps = position[source], let pt = position[target] else { continue }
                let dx = ps.x - pt.x
                let dy = ps.y - pt.y
                let distance = max((dx * dx + dy * dy).squareRoot(), 0.01)
                let attraction = (distance * distance) / k
                let fx = (dx / distance) * attraction
                let fy = (dy / distance) * attraction
                displacement[source]?.x -= fx
                displacement[source]?.y -= fy
                displacement[target]?.x += fx
                displacement[target]?.y += fy
            }

            let temperature = k * (1 - Double(iteration) / Double(iterations))
            for id in ids {
                guard var pos = position[id], let disp = displacement[id] else { continue }
                let dispLength = max((disp.x * disp.x + disp.y * disp.y).squareRoot(), 0.01)
                let cappedLength = min(dispLength, temperature)
                pos.x += (disp.x / dispLength) * cappedLength
                pos.y += (disp.y / dispLength) * cappedLength
                position[id] = pos
            }
        }

        for node in nodes {
            guard let center = position[node.id] else { continue }
            var updated = node
            updated.position = Point2D(x: center.x - node.size.width / 2, y: center.y - node.size.height / 2)
            result.nodes[node.id] = updated
        }
        return result
    }
}
