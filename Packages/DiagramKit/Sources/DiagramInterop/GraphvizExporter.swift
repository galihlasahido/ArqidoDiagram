import Foundation
import DiagramModel

/// Spec §23 "Diagram -> Graphviz DOT".
public enum GraphvizExporter {
    public static func export(_ page: DiagramPage, name: String = "Architecture") -> String {
        let orderedNodes = page.nodeZOrder.compactMap { page.nodes[$0] }
        var lines = ["digraph \(sanitizedIdentifier(name)) {"]
        var idByNode: [NodeID: String] = [:]

        for (index, node) in orderedNodes.enumerated() {
            let id = "n\(index)"
            idByNode[node.id] = id
            let label = displayLabel(node).replacingOccurrences(of: "\"", with: "\\\"")
            lines.append("  \(id) [label=\"\(label)\", shape=\(dotShape(for: node.type))];")
        }

        for edge in page.edgeZOrder.compactMap({ page.edges[$0] }) {
            guard case .node(let sourceID, _) = edge.source, case .node(let targetID, _) = edge.target,
                  let sourceID = idByNode[sourceID], let targetID = idByNode[targetID] else { continue }
            if let label = edge.labels.first?.text, !label.isEmpty {
                lines.append("  \(sourceID) -> \(targetID) [label=\"\(label.replacingOccurrences(of: "\"", with: "\\\""))\"];")
            } else {
                lines.append("  \(sourceID) -> \(targetID);")
            }
        }
        lines.append("}")
        return lines.joined(separator: "\n") + "\n"
    }

    private static func displayLabel(_ node: DiagramNode) -> String {
        node.text?.string.isEmpty == false ? node.text!.string : node.type.rawValue
    }

    private static func dotShape(for type: ShapeType) -> String {
        switch type {
        case .circle, .ellipse, .c4Person, .umlActor:
            return "ellipse"
        case .diamond, .flowchartDecision, .bpmnGateway:
            return "diamond"
        case .flowchartDatabase, .erdEntity, .networkNAS:
            return "cylinder"
        default:
            return "box"
        }
    }

    private static func sanitizedIdentifier(_ name: String) -> String {
        let allowed = name.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : "_" }
        let sanitized = String(allowed)
        return sanitized.isEmpty ? "Architecture" : sanitized
    }
}
