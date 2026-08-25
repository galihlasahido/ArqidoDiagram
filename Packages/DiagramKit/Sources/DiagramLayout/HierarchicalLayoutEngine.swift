import DiagramModel

/// Layered top-down placement: nodes with no incoming edges start at layer
/// 0; every other node's layer becomes one more than the deepest layer of
/// its predecessors (longest-path layering — the standard first cut at a
/// Sugiyama-style layout). Computed by iterative relaxation, capped at
/// `nodes.count` passes, so a cyclic graph still terminates deterministically
/// rather than looping forever. No crossing-minimization pass within a
/// layer — an honest scope cut, not a bug: it still produces a correct,
/// readable top-down layering, just not a crossing-optimal one.
public struct HierarchicalLayoutEngine: LayoutEngine {
    public let displayName = "Hierarchical"
    private let columnSpacing: Double
    private let rowSpacing: Double

    public init(columnSpacing: Double = 220, rowSpacing: Double = 140) {
        self.columnSpacing = columnSpacing
        self.rowSpacing = rowSpacing
    }

    public func layout(_ page: DiagramPage) -> DiagramPage {
        var result = page
        let nodes = LayoutSupport.orderedNodes(page)
        guard !nodes.isEmpty else { return result }

        var layer: [NodeID: Int] = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, 0) })
        let edgePairs: [(NodeID, NodeID)] = page.edges.values.compactMap { edge in
            guard case .node(let sourceID, _) = edge.source, case .node(let targetID, _) = edge.target, sourceID != targetID else { return nil }
            return (sourceID, targetID)
        }
        for _ in 0..<max(1, nodes.count) {
            var changed = false
            for (sourceID, targetID) in edgePairs {
                guard let sourceLayer = layer[sourceID], let targetLayer = layer[targetID] else { continue }
                if sourceLayer + 1 > targetLayer {
                    layer[targetID] = sourceLayer + 1
                    changed = true
                }
            }
            if !changed { break }
        }

        let byLayer = Dictionary(grouping: nodes) { layer[$0.id] ?? 0 }
        for (layerIndex, layerNodes) in byLayer {
            let columnWidth = (layerNodes.map(\.size.width).max() ?? 160) + columnSpacing
            for (column, node) in layerNodes.enumerated() {
                var updated = node
                updated.position = Point2D(x: Double(column) * columnWidth, y: Double(layerIndex) * rowSpacing)
                result.nodes[node.id] = updated
            }
        }
        return result
    }
}
