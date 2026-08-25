import DiagramModel

/// Spec §23/§28 "Diagram -> Mermaid". Emits `graph TD` flowchart syntax —
/// the Mermaid dialect every major Markdown renderer (GitHub, GitLab,
/// Notion, ...) supports natively, which is the whole point of exporting
/// to it. Node shape hints (`(( ))` circle, `{ }` diamond, `[( )]`
/// cylinder) are picked from a coarse read of `ShapeType` so the exported
/// diagram still visually differentiates people/decisions/databases,
/// not just labeled boxes and arrows.
public enum MermaidExporter {
    public static func export(_ page: DiagramPage) -> String {
        let orderedNodes = page.nodeZOrder.compactMap { page.nodes[$0] }
        guard !orderedNodes.isEmpty else { return "graph TD\n" }

        var lines = ["graph TD"]
        var idByNode: [NodeID: String] = [:]
        for (index, node) in orderedNodes.enumerated() {
            let id = "n\(index)"
            idByNode[node.id] = id
            let label = escapeLabel(displayLabel(node))
            lines.append("    \(id)\(shapeBrackets(node.type, label: label))")
        }

        for edge in page.edgeZOrder.compactMap({ page.edges[$0] }) {
            guard case .node(let sourceID, _) = edge.source, case .node(let targetID, _) = edge.target,
                  let sourceMermaidID = idByNode[sourceID], let targetMermaidID = idByNode[targetID] else { continue }
            if let label = edge.labels.first?.text, !label.isEmpty {
                lines.append("    \(sourceMermaidID) -->|\(escapeLabel(label))| \(targetMermaidID)")
            } else {
                lines.append("    \(sourceMermaidID) --> \(targetMermaidID)")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func displayLabel(_ node: DiagramNode) -> String {
        node.text?.string.isEmpty == false ? node.text!.string : node.type.rawValue
    }

    private static func shapeBrackets(_ type: ShapeType, label: String) -> String {
        switch type {
        case .circle, .ellipse, .c4Person, .umlActor, .bpmnStartEvent, .bpmnEndEvent, .bpmnIntermediateEvent:
            return "((\(label)))"
        case .diamond, .flowchartDecision, .bpmnGateway:
            return "{\(label)}"
        case .flowchartDatabase, .erdEntity, .networkNAS:
            return "[(\(label))]"
        default:
            return "[\(label)]"
        }
    }

    private static func escapeLabel(_ label: String) -> String {
        label.replacingOccurrences(of: "\"", with: "'")
    }
}
