import DiagramModel

/// Flags a service connecting directly to a database owned by a different
/// team — the classic "reach into someone else's database instead of going
/// through their API" anti-pattern. Only fires when both nodes have an
/// `Owner` set and they differ; same-owner direct DB access (a service
/// talking to its own database) is completely normal and not flagged.
public struct DirectServiceToDatabaseRule: ValidationRule {
    public let id = "direct-service-to-database"
    public let name = "Direct Service-to-Database Access"

    public init() {}

    public func evaluate(_ page: DiagramPage) -> [ValidationIssue] {
        ValidationSupport.nodePairs(page).compactMap { edge, a, b in
            let service: DiagramNode
            let database: DiagramNode
            if NodeRole.of(a) == .service && NodeRole.of(b) == .database {
                service = a
                database = b
            } else if NodeRole.of(b) == .service && NodeRole.of(a) == .database {
                service = b
                database = a
            } else {
                return nil
            }
            guard let serviceOwner = service.metadata.owner, let databaseOwner = database.metadata.owner,
                  !serviceOwner.isEmpty, !databaseOwner.isEmpty, serviceOwner != databaseOwner else { return nil }

            return ValidationIssue(
                ruleID: id,
                ruleName: name,
                severity: .error,
                message: "Service \"\(ValidationSupport.displayName(service))\" (owned by \(serviceOwner)) connects directly to database \"\(ValidationSupport.displayName(database))\" (owned by \(databaseOwner)) without an intermediary API.",
                nodeIDs: [service.id, database.id],
                edgeIDs: [edge.id]
            )
        }
    }
}
