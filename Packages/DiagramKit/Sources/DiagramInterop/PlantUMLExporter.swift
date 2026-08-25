import DiagramModel

/// Spec §23/§28 "Diagram -> PlantUML". Uses PlantUML's generic deployment-
/// diagram element keywords (`actor`/`database`/`rectangle`) rather than
/// its more specialized diagram modes, since a `DiagramPage` can mix UML/
/// C4/network/security shapes freely and those three keywords cover that
/// mix legibly without needing to pick one PlantUML diagram type up front.
public enum PlantUMLExporter {
    public static func export(_ page: DiagramPage) -> String {
        let orderedNodes = page.nodeZOrder.compactMap { page.nodes[$0] }
        var lines = ["@startuml"]
        var idByNode: [NodeID: String] = [:]

        for (index, node) in orderedNodes.enumerated() {
            let id = "n\(index)"
            idByNode[node.id] = id
            let label = displayLabel(node).replacingOccurrences(of: "\"", with: "'")
            lines.append("\(keyword(for: node.type)) \"\(label)\" as \(id)")
        }

        for edge in page.edgeZOrder.compactMap({ page.edges[$0] }) {
            guard case .node(let sourceID, _) = edge.source, case .node(let targetID, _) = edge.target,
                  let sourceID = idByNode[sourceID], let targetID = idByNode[targetID] else { continue }
            if let label = edge.labels.first?.text, !label.isEmpty {
                lines.append("\(sourceID) --> \(targetID) : \(label.replacingOccurrences(of: "\"", with: "'"))")
            } else {
                lines.append("\(sourceID) --> \(targetID)")
            }
        }
        lines.append("@enduml")
        return lines.joined(separator: "\n") + "\n"
    }

    private static func displayLabel(_ node: DiagramNode) -> String {
        node.text?.string.isEmpty == false ? node.text!.string : node.type.rawValue
    }

    private static func keyword(for type: ShapeType) -> String {
        switch type {
        case .c4Person, .umlActor:
            return "actor"
        case .flowchartDatabase, .erdEntity, .networkNAS:
            return "database"
        default:
            return "rectangle"
        }
    }
}
