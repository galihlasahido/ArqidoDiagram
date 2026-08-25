import Foundation
import DiagramModel
import DiagramLayout

public enum AIArchitectError: Error, Sendable {
    case couldNotParseResponse(String)
}

/// Owns the spec's exact pipeline: "Prompt -> LLM -> Structured Diagram
/// Model -> Validation -> Layout Engine -> Native Diagram Objects" (minus
/// Validation, which the caller runs afterward via `DiagramValidation`
/// against the real, inserted nodes — running it here against the
/// not-yet-placed intermediate spec would validate something the user
/// never actually sees). "AI must NOT generate only a raster image": this
/// always returns real `DiagramNode`/`DiagramEdge` values.
public struct AIArchitect: Sendable {
    private let provider: AIProvider

    public init(provider: AIProvider) {
        self.provider = provider
    }

    private static let diagramSystemPrompt = """
    You are an assistant embedded in a native macOS enterprise architecture diagramming app. \
    You translate a request into a diagram by responding with ONLY a single JSON object — no \
    prose, no markdown code fences, nothing before or after it. The schema is:
    {"nodes":[{"id":"short_stable_id","label":"Human Readable Name","type":"semantic type"}],
     "edges":[{"from":"id","to":"id","label":"optional label"}]}
    Rules:
    - "type" should be a short lowercase architectural role such as: service, database, gateway, \
    firewall, waf, load balancer, cache, queue, external, actor, container, kubernetes pod, \
    entity, event, task, decision, class, interface.
    - Every edge's "from"/"to" must reference a node "id" that appears in "nodes".
    - Prefer 3-12 nodes for a typical request; do not pad with unrelated components.
    - Output raw JSON only.
    """

    public func generateDiagram(
        prompt: String,
        layout: any LayoutEngine = HierarchicalLayoutEngine()
    ) async throws -> (nodes: [DiagramNode], edges: [DiagramEdge]) {
        let raw = try await provider.complete(system: Self.diagramSystemPrompt, user: prompt, maxTokens: 3000)
        let spec = try Self.parseSpec(from: raw)
        return Self.materialize(spec, layout: layout)
    }

    /// Exposed separately so the ⌘K command bar's "Convert diagram"/"Add
    /// missing components" intents can go straight from an already-parsed
    /// spec (e.g. one produced by `DiagramInterop`) through the same
    /// materialize+layout step, without a redundant LLM round trip.
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

    static func parseSpec(from raw: String) throws -> GeneratedDiagramSpec {
        guard let jsonText = JSONExtraction.firstJSONObject(in: raw), let data = jsonText.data(using: .utf8) else {
            throw AIArchitectError.couldNotParseResponse(raw)
        }
        do {
            return try JSONDecoder().decode(GeneratedDiagramSpec.self, from: data)
        } catch {
            throw AIArchitectError.couldNotParseResponse(raw)
        }
    }

    // MARK: - Explain / analyze / document (free-form prose, no schema)

    public func explain(summary: String) async throws -> String {
        try await provider.complete(
            system: "You are an assistant embedded in a native macOS architecture diagramming app. Explain the given diagram clearly and concisely in plain prose for an engineer unfamiliar with it.",
            user: summary,
            maxTokens: 1200
        )
    }

    public func writeDocumentation(summary: String) async throws -> String {
        try await provider.complete(
            system: "You are an assistant embedded in a native macOS architecture diagramming app. Write clear Markdown documentation describing the given architecture, its components, and how they relate.",
            user: summary,
            maxTokens: 2000
        )
    }
}
