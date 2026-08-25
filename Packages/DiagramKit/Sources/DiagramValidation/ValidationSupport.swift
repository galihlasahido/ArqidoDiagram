import DiagramModel

enum ValidationSupport {
    static func nodePairs(_ page: DiagramPage) -> [(edge: DiagramEdge, source: DiagramNode, target: DiagramNode)] {
        page.edges.values.compactMap { edge in
            guard case .node(let sourceID, _) = edge.source, case .node(let targetID, _) = edge.target,
                  let source = page.nodes[sourceID], let target = page.nodes[targetID] else { return nil }
            return (edge, source, target)
        }
    }

    static func displayName(_ node: DiagramNode) -> String {
        if let text = node.text?.string, !text.isEmpty { return text }
        return node.type.rawValue
    }
}
