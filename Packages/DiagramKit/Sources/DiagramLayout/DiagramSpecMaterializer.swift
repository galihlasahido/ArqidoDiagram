import DiagramModel

/// Turns a `GeneratedDiagramSpec` (the common intermediate format both
/// `DiagramAI` and `DiagramInterop`'s importers produce) into real,
/// laid-out `DiagramNode`/`DiagramEdge` values ready to insert into a
/// canvas — shared here so every "X -> Diagram" path (an LLM prompt, a SQL
/// schema, an OpenAPI doc, a Kubernetes manifest, ...) positions its
/// output the same way instead of each reimplementing placement.
public enum DiagramSpecMaterializer {
    public static func materialize(
        _ spec: GeneratedDiagramSpec,
        layout: any LayoutEngine = HierarchicalLayoutEngine()
    ) -> (nodes: [DiagramNode], edges: [DiagramEdge]) {
        var idMap: [String: NodeID] = [:]
        var page = DiagramPage(name: "", order: 0)

        for (index, nodeSpec) in spec.nodes.enumerated() {
            let node = DiagramNode(
                type: SemanticTypeShapeMapping.shapeType(for: nodeSpec.type),
                position: Point2D(x: 0, y: 0),
                size: Size2D(width: 160, height: 90),
                text: TextContent(string: nodeSpec.label),
                metadata: Metadata(semanticType: nodeSpec.type),
                zIndex: index
            )
            idMap[nodeSpec.id] = node.id
            page.nodes[node.id] = node
            page.nodeZOrder.append(node.id)
        }

        for edgeSpec in spec.edges {
            guard let sourceID = idMap[edgeSpec.from], let targetID = idMap[edgeSpec.to] else { continue }
            var edge = DiagramEdge(source: .node(sourceID, portID: nil), target: .node(targetID, portID: nil))
            if let label = edgeSpec.label, !label.isEmpty {
                edge.labels = [EdgeLabel(text: label)]
            }
            page.edges[edge.id] = edge
            page.edgeZOrder.append(edge.id)
        }

        let laidOut = layout.layout(page)
        let orderedNodeIDs = spec.nodes.compactMap { idMap[$0.id] }
        let nodes = orderedNodeIDs.compactMap { laidOut.nodes[$0] }
        let edges = laidOut.edgeZOrder.compactMap { laidOut.edges[$0] }
        return (nodes, edges)
    }
}
