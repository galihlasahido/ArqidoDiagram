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
        return DiagramSpecMaterializer.materialize(spec, layout: layout)
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
