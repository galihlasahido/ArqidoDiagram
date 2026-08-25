import DiagramModel

/// Flags any edge directly connecting an externally-facing node (internet,
/// external system) straight to a database, with nothing in between — the
/// most literal reading of "public database".
public struct PublicDatabaseRule: ValidationRule {
    public let id = "public-database"
    public let name = "Public Database"

    public init() {}

    public func evaluate(_ page: DiagramPage) -> [ValidationIssue] {
        ValidationSupport.nodePairs(page).compactMap { edge, a, b in
            let roleA = NodeRole.of(a)
            let roleB = NodeRole.of(b)
            guard (roleA == .external && roleB == .database) || (roleA == .database && roleB == .external) else { return nil }
            let database = roleA == .database ? a : b
            return ValidationIssue(
                ruleID: id,
                ruleName: name,
                severity: .error,
                message: "Database \"\(ValidationSupport.displayName(database))\" is directly reachable from an external/internet node.",
                nodeIDs: [a.id, b.id],
                edgeIDs: [edge.id]
            )
        }
    }
}
