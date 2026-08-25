import DiagramModel

/// Flags every edge that lets external traffic reach internal
/// infrastructure directly, when the page has no firewall node anywhere —
/// a page-wide "is there a firewall at all" check (not full path analysis:
/// a firewall elsewhere in the diagram that this particular edge doesn't
/// actually pass through would still silence this, which is a deliberate,
/// documented scope cut rather than a full network path tracer).
public struct MissingFirewallRule: ValidationRule {
    public let id = "missing-firewall"
    public let name = "Missing Firewall"

    public init() {}

    public func evaluate(_ page: DiagramPage) -> [ValidationIssue] {
        let hasFirewall = page.nodes.values.contains { NodeRole.of($0) == .firewall }
        guard !hasFirewall else { return [] }

        return ValidationSupport.nodePairs(page).compactMap { edge, a, b in
            let external: DiagramNode
            let exposed: DiagramNode
            if NodeRole.of(a) == .external {
                external = a
                exposed = b
            } else if NodeRole.of(b) == .external {
                external = b
                exposed = a
            } else {
                return nil
            }
            let exposedRole = NodeRole.of(exposed)
            guard exposedRole == .service || exposedRole == .database || exposedRole == .cache || exposedRole == .queue else { return nil }
            return ValidationIssue(
                ruleID: id,
                ruleName: name,
                severity: .warning,
                message: "\"\(ValidationSupport.displayName(exposed))\" is reachable from \"\(ValidationSupport.displayName(external))\" but the diagram has no firewall.",
                nodeIDs: [a.id, b.id],
                edgeIDs: [edge.id]
            )
        }
    }
}
