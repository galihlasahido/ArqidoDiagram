import DiagramModel

/// Spec §24 "Architecture-as-Code": two-way conversion between a diagram
/// and exactly the YAML shape shown there —
/// ```yaml
/// architecture:
///   name: Payment Platform
/// services:
///   - name: API Gateway
///     type: gateway
/// connections:
///   - from: API Gateway
///     to: Payment Service
/// ```
/// — chosen as the git-friendly text format the spec explicitly calls out
/// ("This allows diagrams to be version-controlled with Git").
public enum ArchitectureYAMLImporter {
    public static func parse(_ yaml: String) -> (name: String?, spec: GeneratedDiagramSpec) {
        let parsed = MiniYAML.parse(yaml)
        let name = parsed["architecture"]?["name"]?.stringValue

        var nodes: [GeneratedNodeSpec] = []
        if case .sequence(let serviceEntries) = parsed["services"] ?? .sequence([]) {
            for entry in serviceEntries {
                guard let serviceName = entry["name"]?.stringValue else { continue }
                nodes.append(GeneratedNodeSpec(id: serviceName, label: serviceName, type: entry["type"]?.stringValue ?? "service"))
            }
        }

        var edges: [GeneratedEdgeSpec] = []
        if case .sequence(let connectionEntries) = parsed["connections"] ?? .sequence([]) {
            for entry in connectionEntries {
                guard let from = entry["from"]?.stringValue, let to = entry["to"]?.stringValue else { continue }
                edges.append(GeneratedEdgeSpec(from: from, to: to, label: entry["label"]?.stringValue))
            }
        }

        return (name, GeneratedDiagramSpec(nodes: nodes, edges: edges))
    }
}

public enum ArchitectureYAMLExporter {
    public static func export(_ page: DiagramPage, architectureName: String) -> String {
        var lines: [String] = []
        lines.append("architecture:")
        lines.append("  name: \(yamlScalar(architectureName))")
        lines.append("")

        let orderedNodes = page.nodeZOrder.compactMap { page.nodes[$0] }
        var labelByNodeID: [NodeID: String] = [:]
        lines.append("services:")
        if orderedNodes.isEmpty {
            lines[lines.count - 1] += " []"
        } else {
            for node in orderedNodes {
                let label = node.text?.string.isEmpty == false ? node.text!.string : node.type.rawValue
                labelByNodeID[node.id] = label
                lines.append("  - name: \(yamlScalar(label))")
                lines.append("    type: \(yamlScalar(node.metadata.semanticType ?? node.type.rawValue))")
            }
        }

        lines.append("")
        let orderedEdges = page.edgeZOrder.compactMap { page.edges[$0] }
        lines.append("connections:")
        let connectionLines: [String] = orderedEdges.compactMap { edge in
            guard case .node(let sourceID, _) = edge.source, case .node(let targetID, _) = edge.target,
                  let sourceLabel = labelByNodeID[sourceID], let targetLabel = labelByNodeID[targetID] else { return nil }
            var entry = "  - from: \(yamlScalar(sourceLabel))\n    to: \(yamlScalar(targetLabel))"
            if let label = edge.labels.first?.text, !label.isEmpty {
                entry += "\n    label: \(yamlScalar(label))"
            }
            return entry
        }
        if connectionLines.isEmpty {
            lines[lines.count - 1] += " []"
        } else {
            lines.append(contentsOf: connectionLines)
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private static func yamlScalar(_ value: String) -> String {
        let needsQuoting = value.contains(":") || value.contains("#") || value.isEmpty
            || value.hasPrefix(" ") || value.hasSuffix(" ") || value.hasPrefix("\"") || value.hasPrefix("'")
        guard needsQuoting else { return value }
        let escaped = value.replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
