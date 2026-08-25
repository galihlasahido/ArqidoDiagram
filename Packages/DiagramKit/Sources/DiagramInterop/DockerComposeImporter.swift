import DiagramModel

/// Spec §22/§27 "Docker Compose -> Container Architecture". Each service
/// becomes a container node; `depends_on` (either the short list form or
/// the long mapping form with per-dependency conditions) becomes an edge —
/// real depends-on relationships, not just a flat list of boxes.
public enum DockerComposeImporter {
    public static func parse(_ compose: String) -> GeneratedDiagramSpec {
        let parsed = MiniYAML.parse(compose)
        guard case .mapping(let serviceEntries) = parsed["services"] ?? .mapping([]) else {
            return GeneratedDiagramSpec(nodes: [], edges: [])
        }

        var nodes: [GeneratedNodeSpec] = []
        var edges: [GeneratedEdgeSpec] = []

        for (name, definition) in serviceEntries {
            nodes.append(GeneratedNodeSpec(id: name, label: name, type: "container"))
            for dependency in dependsOnNames(definition["depends_on"]) {
                edges.append(GeneratedEdgeSpec(from: name, to: dependency, label: "depends on"))
            }
        }

        return GeneratedDiagramSpec(nodes: nodes, edges: edges)
    }

    /// `depends_on` is either `["a", "b"]` or `{a: {condition: ...}, b: {}}`
    /// — both are valid Compose syntax, so both need to resolve to the
    /// same list of dependency names.
    private static func dependsOnNames(_ value: YAMLValue?) -> [String] {
        guard let value else { return [] }
        if case .sequence(let items) = value {
            return items.compactMap(\.stringValue)
        }
        if case .mapping(let pairs) = value {
            return pairs.map(\.key)
        }
        return []
    }
}
