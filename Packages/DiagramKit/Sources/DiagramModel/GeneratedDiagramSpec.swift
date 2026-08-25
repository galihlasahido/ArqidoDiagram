import Foundation

/// The LLM's structured output — deliberately small and generic (an id/
/// label/type per node, a from/to/label per edge) rather than asking the
/// model to emit our full `DiagramNode`/`DiagramEdge` JSON directly. Two
/// reasons: models are far more reliable at a handful of plain fields than
/// a large nested schema, and this shape is exactly the vocabulary
/// `Metadata.semanticType`/`NodeRole` already use — a generated "database"
/// node is immediately something Architecture Validation understands, no
/// separate mapping step for that half of it.
public struct GeneratedNodeSpec: Codable, Sendable {
    public let id: String
    public let label: String
    public let type: String

    public init(id: String, label: String, type: String) {
        self.id = id
        self.label = label
        self.type = type
    }
}

public struct GeneratedEdgeSpec: Codable, Sendable {
    public let from: String
    public let to: String
    public let label: String?

    public init(from: String, to: String, label: String? = nil) {
        self.from = from
        self.to = to
        self.label = label
    }
}

public struct GeneratedDiagramSpec: Codable, Sendable {
    public let nodes: [GeneratedNodeSpec]
    public let edges: [GeneratedEdgeSpec]

    public init(nodes: [GeneratedNodeSpec], edges: [GeneratedEdgeSpec]) {
        self.nodes = nodes
        self.edges = edges
    }
}
