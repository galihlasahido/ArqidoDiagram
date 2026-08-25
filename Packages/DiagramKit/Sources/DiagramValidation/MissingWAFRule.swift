import DiagramModel

/// Flags edges where external traffic reaches a service directly, when the
/// page has no WAF node anywhere — same page-wide "is one present at all"
/// scope as `MissingFirewallRule`, specific to web-facing services rather
/// than any internal component.
public struct MissingWAFRule: ValidationRule {
    public let id = "missing-waf"
    public let name = "Missing WAF"

    public init() {}

    public func evaluate(_ page: DiagramPage) -> [ValidationIssue] {
        let hasWAF = page.nodes.values.contains { NodeRole.of($0) == .waf }
        guard !hasWAF else { return [] }

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
            guard NodeRole.of(exposed) == .service else { return nil }
            return ValidationIssue(
                ruleID: id,
                ruleName: name,
                severity: .warning,
                message: "Service \"\(ValidationSupport.displayName(exposed))\" is exposed to \"\(ValidationSupport.displayName(external))\" but the diagram has no WAF.",
                nodeIDs: [a.id, b.id],
                edgeIDs: [edge.id]
            )
        }
    }
}
