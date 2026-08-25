import Foundation
import DiagramModel

/// Spec §22/§27 "SQL -> ERD". A deterministic parser for standard
/// `CREATE TABLE` DDL — not a full SQL dialect parser (no triggers, views,
/// CHECK expression parsing, etc.), but real, correct handling of the
/// common case: columns, inline/standalone PRIMARY KEY, inline/standalone
/// FOREIGN KEY ... REFERENCES. Produces genuine Chen-notation ERD content
/// (one entity node per table, one attribute/key node per column, edges
/// for "has attribute" and for foreign-key relationships) matching this
/// app's existing ERD shape set exactly.
public enum SQLSchemaImporter {
    public static func parse(_ sql: String) -> GeneratedDiagramSpec {
        var nodes: [GeneratedNodeSpec] = []
        var edges: [GeneratedEdgeSpec] = []

        for table in extractTables(from: sql) {
            let entityID = "table_\(table.name)"
            nodes.append(GeneratedNodeSpec(id: entityID, label: table.name, type: "entity"))

            for column in table.columns {
                let columnID = "\(entityID)_\(column.name)"
                let type = column.isPrimaryKey ? "primary key" : (column.references != nil ? "foreign key" : "attribute")
                nodes.append(GeneratedNodeSpec(id: columnID, label: column.name, type: type))
                edges.append(GeneratedEdgeSpec(from: entityID, to: columnID))

                if let reference = column.references {
                    edges.append(GeneratedEdgeSpec(from: columnID, to: "table_\(reference.table)", label: "references"))
                }
            }
        }

        return GeneratedDiagramSpec(nodes: nodes, edges: edges)
    }

    // MARK: - Parsing

    struct Column {
        let name: String
        var isPrimaryKey: Bool
        var references: (table: String, column: String)?
    }

    struct Table {
        let name: String
        var columns: [Column]
    }

    private static func extractTables(from sql: String) -> [Table] {
        let stripped = stripComments(sql)
        var tables: [Table] = []

        // Find every "CREATE TABLE <name> (" then balance-match the parens
        // that follow to get exactly that table's body.
        let pattern = #"(?i)CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?[`"\[]?(\w+)[`"\]]?\s*\("#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(stripped.startIndex..., in: stripped)

        for match in regex.matches(in: stripped, range: nsRange) {
            guard let nameRange = Range(match.range(at: 1), in: stripped),
                  let openParenRange = Range(match.range, in: stripped) else { continue }
            let tableName = String(stripped[nameRange])
            let bodyStart = stripped.index(before: openParenRange.upperBound)
            guard let body = balancedParenBody(in: stripped, openingAt: bodyStart) else { continue }

            let entries = topLevelEntries(of: body)
            let columns = entries.compactMap { parseEntry($0) }
            var table = Table(name: tableName, columns: [])
            var primaryKeyNames: Set<String> = []
            var tableLevelReferences: [String: (String, String)] = [:]

            for entry in entries {
                let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.uppercased().hasPrefix("PRIMARY KEY") {
                    primaryKeyNames.formUnion(columnNames(inParensOf: trimmed))
                } else if trimmed.uppercased().hasPrefix("FOREIGN KEY") {
                    if let (localColumns, refTable, refColumns) = parseTableLevelForeignKey(trimmed) {
                        for (index, local) in localColumns.enumerated() {
                            let refColumn = index < refColumns.count ? refColumns[index] : (refColumns.first ?? local)
                            tableLevelReferences[local] = (refTable, refColumn)
                        }
                    }
                }
            }

            for var column in columns {
                if primaryKeyNames.contains(column.name) { column.isPrimaryKey = true }
                if let reference = tableLevelReferences[column.name] {
                    column.references = reference
                }
                table.columns.append(column)
            }
            tables.append(table)
        }
        return tables
    }

    private static func parseEntry(_ entry: String) -> Column? {
        let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
        let upper = trimmed.uppercased()
        guard !upper.hasPrefix("PRIMARY KEY"), !upper.hasPrefix("FOREIGN KEY"),
              !upper.hasPrefix("UNIQUE"), !upper.hasPrefix("CONSTRAINT"), !upper.hasPrefix("CHECK") else { return nil }

        let tokens = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" })
        guard let first = tokens.first else { return nil }
        let name = first.trimmingCharacters(in: CharacterSet(charactersIn: "`\"[]"))
        guard !name.isEmpty else { return nil }

        var column = Column(name: name, isPrimaryKey: upper.contains("PRIMARY KEY"), references: nil)
        if let referencesRange = trimmed.range(of: "REFERENCES", options: .caseInsensitive) {
            let afterReferences = trimmed[referencesRange.upperBound...]
            if let (table, col) = parseReferenceTarget(String(afterReferences)) {
                column.references = (table, col)
            }
        }
        return column
    }

    private static func parseReferenceTarget(_ text: String) -> (String, String)? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let openParen = trimmed.firstIndex(of: "("), let closeParen = trimmed.firstIndex(of: ")") else {
            let tableName = trimmed.split(whereSeparator: { $0 == " " || $0 == "," }).first ?? ""
            let cleaned = tableName.trimmingCharacters(in: CharacterSet(charactersIn: "`\"[];"))
            guard !cleaned.isEmpty else { return nil }
            return (cleaned, "id")
        }
        let tableName = trimmed[trimmed.startIndex..<openParen].trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "`\"[]"))
        let columnName = trimmed[trimmed.index(after: openParen)..<closeParen].trimmingCharacters(in: .whitespaces)
        guard !tableName.isEmpty else { return nil }
        return (tableName, columnName.isEmpty ? "id" : columnName)
    }

    private static func parseTableLevelForeignKey(_ text: String) -> (local: [String], table: String, columns: [String])? {
        guard let firstOpen = text.firstIndex(of: "("), let firstClose = text[firstOpen...].firstIndex(of: ")") else { return nil }
        let localColumns = columnNamesAfterTable(String(text[text.startIndex...firstClose]))
        guard let referencesRange = text.range(of: "REFERENCES", options: .caseInsensitive, range: firstClose..<text.endIndex) else { return nil }
        let afterReferences = String(text[referencesRange.upperBound...])
        guard let (table, _) = parseReferenceTarget(afterReferences) else { return nil }
        let refColumns = columnNamesAfterTable(afterReferences)
        return (localColumns, table, refColumns.isEmpty ? ["id"] : refColumns)
    }

    private static func columnNames(inParensOf text: String) -> Set<String> {
        guard let open = text.firstIndex(of: "("), let close = text[open...].firstIndex(of: ")") else { return [] }
        let inner = text[text.index(after: open)..<close]
        return Set(inner.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "`\"[]"))
        })
    }

    private static func columnNamesAfterTable(_ text: String) -> [String] {
        guard let open = text.firstIndex(of: "("), let close = text[open...].firstIndex(of: ")") else { return [] }
        let inner = text[text.index(after: open)..<close]
        return inner.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "`\"[]"))
        }
    }

    /// Splits a `CREATE TABLE` body on top-level commas only — a comma
    /// inside `VARCHAR(255)` or a composite `FOREIGN KEY (a, b)` must not
    /// split the entry it belongs to.
    private static func topLevelEntries(of body: String) -> [String] {
        var entries: [String] = []
        var depth = 0
        var current = ""
        for character in body {
            switch character {
            case "(":
                depth += 1
                current.append(character)
            case ")":
                depth -= 1
                current.append(character)
            case "," where depth == 0:
                entries.append(current)
                current = ""
            default:
                current.append(character)
            }
        }
        if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            entries.append(current)
        }
        return entries
    }

    private static func balancedParenBody(in text: String, openingAt openParenIndex: String.Index) -> String? {
        var depth = 0
        var index = openParenIndex
        let bodyStart = text.index(after: openParenIndex)
        while index < text.endIndex {
            if text[index] == "(" { depth += 1 }
            if text[index] == ")" {
                depth -= 1
                if depth == 0 {
                    return String(text[bodyStart..<index])
                }
            }
            index = text.index(after: index)
        }
        return nil
    }

    private static func stripComments(_ sql: String) -> String {
        var lines = sql.components(separatedBy: "\n")
        for i in lines.indices {
            if let range = lines[i].range(of: "--") {
                lines[i] = String(lines[i][lines[i].startIndex..<range.lowerBound])
            }
        }
        var result = lines.joined(separator: "\n")
        while let start = result.range(of: "/*"), let end = result.range(of: "*/", range: start.upperBound..<result.endIndex) {
            result.removeSubrange(start.lowerBound..<end.upperBound)
        }
        return result
    }
}
