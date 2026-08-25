import DiagramModel

/// Spec §22/§27 "OpenAPI -> API Diagram". A central node for the API
/// itself (from `info.title`), one node per path grouped by its first tag
/// (falling back to the path itself when untagged) so a large API doesn't
/// become one undifferentiated cloud of boxes, and one node per component
/// schema referenced from at least one operation — real API structure, not
/// just an endpoint list.
public enum OpenAPIImporter {
    public static func parse(_ document: String) -> GeneratedDiagramSpec {
        let parsed = MiniYAML.parse(document)
        let apiTitle = parsed["info"]?["title"]?.stringValue ?? "API"
        let apiID = "api_root"

        var nodes: [GeneratedNodeSpec] = [GeneratedNodeSpec(id: apiID, label: apiTitle, type: "gateway")]
        var edges: [GeneratedEdgeSpec] = []
        var seenTags: Set<String> = []

        guard case .mapping(let pathEntries) = parsed["paths"] ?? .mapping([]) else {
            return GeneratedDiagramSpec(nodes: nodes, edges: edges)
        }

        for (path, operations) in pathEntries {
            let tag = firstTag(of: operations) ?? path
            let tagID = "tag_\(tag)"
            if seenTags.insert(tag).inserted {
                nodes.append(GeneratedNodeSpec(id: tagID, label: tag, type: "component"))
                edges.append(GeneratedEdgeSpec(from: apiID, to: tagID))
            }
        }

        if case .mapping(let schemas) = parsed["components"]?["schemas"] ?? .mapping([]) {
            for (schemaName, _) in schemas {
                let schemaID = "schema_\(schemaName)"
                nodes.append(GeneratedNodeSpec(id: schemaID, label: schemaName, type: "entity"))
            }
        }

        return GeneratedDiagramSpec(nodes: nodes, edges: edges)
    }

    private static let httpMethods: Set<String> = ["get", "post", "put", "patch", "delete", "options", "head"]

    private static func firstTag(of pathItem: YAMLValue) -> String? {
        guard case .mapping(let operations) = pathItem else { return nil }
        for (method, operation) in operations where httpMethods.contains(method.lowercased()) {
            if let tag = operation["tags"]?.arrayValue?.first?.stringValue {
                return tag
            }
        }
        return nil
    }
}
