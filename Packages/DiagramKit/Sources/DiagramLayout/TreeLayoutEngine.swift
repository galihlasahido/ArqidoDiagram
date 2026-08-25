import DiagramModel

/// Assumes (or degrades gracefully from) a tree: each node's parent is the
/// source of its first incoming edge — `HierarchicalLayoutEngine` is what
/// handles genuine multi-parent DAGs. Children are laid out left-to-right
/// under their parent, each parent centered over its children's combined
/// span (the classic Reingold-Tilford-style centered-tree layout). Nodes
/// unreachable from any root (isolated cycles) are parked in a fallback row
/// below the tree rather than silently skipped.
public struct TreeLayoutEngine: LayoutEngine {
    public let displayName = "Tree"
    private let siblingSpacing: Double
    private let levelSpacing: Double

    public init(siblingSpacing: Double = 40, levelSpacing: Double = 140) {
        self.siblingSpacing = siblingSpacing
        self.levelSpacing = levelSpacing
    }

    public func layout(_ page: DiagramPage) -> DiagramPage {
        var result = page
        let nodes = LayoutSupport.orderedNodes(page)
        guard !nodes.isEmpty else { return result }

        var parent: [NodeID: NodeID] = [:]
        for edge in page.edges.values {
            guard case .node(let sourceID, _) = edge.source, case .node(let targetID, _) = edge.target, sourceID != targetID else { continue }
            if parent[targetID] == nil { parent[targetID] = sourceID }
        }
        let orderIndex = Dictionary(uniqueKeysWithValues: nodes.enumerated().map { ($1.id, $0) })
        var children: [NodeID: [NodeID]] = [:]
        for (child, p) in parent { children[p, default: []].append(child) }
        for key in children.keys {
            children[key]?.sort { (orderIndex[$0] ?? 0) < (orderIndex[$1] ?? 0) }
        }
        let sizeByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0.size) })
        let roots = nodes.filter { parent[$0.id] == nil }.map(\.id)

        var subtreeWidth: [NodeID: Double] = [:]
        func computeWidth(_ id: NodeID) -> Double {
            let ownWidth = sizeByID[id]?.width ?? 160
            guard let kids = children[id], !kids.isEmpty else {
                subtreeWidth[id] = ownWidth
                return ownWidth
            }
            let childrenWidth = kids.map(computeWidth).reduce(0, +) + siblingSpacing * Double(kids.count - 1)
            let width = max(ownWidth, childrenWidth)
            subtreeWidth[id] = width
            return width
        }
        for root in roots { _ = computeWidth(root) }

        var visited: Set<NodeID> = []
        func place(_ id: NodeID, leftEdge: Double, depth: Int) {
            visited.insert(id)
            let width = subtreeWidth[id] ?? (sizeByID[id]?.width ?? 160)
            let ownWidth = sizeByID[id]?.width ?? 160
            if var node = result.nodes[id] {
                node.position = Point2D(x: leftEdge + (width - ownWidth) / 2, y: Double(depth) * levelSpacing)
                result.nodes[id] = node
            }
            guard let kids = children[id], !kids.isEmpty else { return }
            var cursor = leftEdge
            for kid in kids {
                place(kid, leftEdge: cursor, depth: depth + 1)
                cursor += (subtreeWidth[kid] ?? (sizeByID[kid]?.width ?? 160)) + siblingSpacing
            }
        }

        var rootCursor: Double = 0
        for root in roots {
            place(root, leftEdge: rootCursor, depth: 0)
            rootCursor += (subtreeWidth[root] ?? 160) + siblingSpacing * 2
        }

        let leftover = nodes.filter { !visited.contains($0.id) }
        let fallbackRow = Double(nodes.count) * levelSpacing
        for (index, node) in leftover.enumerated() {
            var updated = node
            updated.position = Point2D(x: Double(index) * (node.size.width + siblingSpacing), y: fallbackRow)
            result.nodes[node.id] = updated
        }
        return result
    }
}
