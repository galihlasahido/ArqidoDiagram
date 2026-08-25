import Foundation
import DiagramModel

/// Spec §23/§28 "ERD -> SQL". The inverse of `SQLSchemaImporter`: walks
/// each `erdEntity` node's "has attribute" edges to find its columns, and
/// each `erdForeignKey` column's "references" edge to find the target
/// table. Column *types* aren't round-tripped — Chen-notation ERD (this
/// app's ERD model) only distinguishes entity/attribute/primary key/
/// foreign key, not a SQL type per column, so every generated column
/// defaults to `TEXT` (or `INTEGER` for a primary key, the common
/// convention) — an honest limitation of the conceptual model, not a bug.
public enum SQLExporter {
    public static func export(_ page: DiagramPage) -> String {
        let entities = page.nodeZOrder.compactMap { page.nodes[$0] }.filter { $0.type == .erdEntity }
        guard !entities.isEmpty else { return "" }

        let statements = entities.map { entity in createTableStatement(for: entity, in: page) }
        return statements.joined(separator: "\n\n") + "\n"
    }

    private static func createTableStatement(for entity: DiagramNode, in page: DiagramPage) -> String {
        let attributeIDs = page.edges.values.compactMap { edge -> NodeID? in
            guard case .node(let sourceID, _) = edge.source, sourceID == entity.id,
                  case .node(let targetID, _) = edge.target else { return nil }
            return targetID
        }

        let columnLines: [String] = attributeIDs.compactMap { attributeID in
            guard let attribute = page.nodes[attributeID],
                  [ShapeType.erdAttribute, .erdPrimaryKey, .erdForeignKey].contains(attribute.type) else { return nil }
            var line = "  \(identifier(displayLabel(attribute)))"
            switch attribute.type {
            case .erdPrimaryKey:
                line += " INTEGER PRIMARY KEY"
            case .erdForeignKey:
                line += " TEXT"
                if let referencedTable = referencedEntity(of: attributeID, in: page) {
                    line += " REFERENCES \(identifier(displayLabel(referencedTable)))"
                }
            default:
                line += " TEXT"
            }
            return line
        }

        let body = columnLines.isEmpty ? "  id INTEGER PRIMARY KEY" : columnLines.joined(separator: ",\n")
        return "CREATE TABLE \(identifier(displayLabel(entity))) (\n\(body)\n);"
    }

    private static func referencedEntity(of foreignKeyNodeID: NodeID, in page: DiagramPage) -> DiagramNode? {
        for edge in page.edges.values {
            guard case .node(let sourceID, _) = edge.source, sourceID == foreignKeyNodeID,
                  case .node(let targetID, _) = edge.target, let target = page.nodes[targetID],
                  target.type == .erdEntity else { continue }
            return target
        }
        return nil
    }

    private static func displayLabel(_ node: DiagramNode) -> String {
        node.text?.string.isEmpty == false ? node.text!.string : node.type.rawValue
    }

    private static func identifier(_ label: String) -> String {
        let lowered = label.lowercased().replacingOccurrences(of: " ", with: "_")
        let allowed = lowered.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) || $0 == "_" ? Character($0) : "_" }
        let sanitized = String(allowed)
        return sanitized.isEmpty ? "column" : sanitized
    }
}
