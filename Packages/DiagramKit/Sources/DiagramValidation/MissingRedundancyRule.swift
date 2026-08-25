import DiagramModel

/// Flags a node marked high/critical criticality that is the *only* node
/// of its architectural role on the page — a single point of failure for
/// something the author themselves called critical. Nodes without a
/// criticality set are never flagged (no basis to judge them), which keeps
/// this rule from being noisy on diagrams that haven't been annotated yet.
public struct MissingRedundancyRule: ValidationRule {
    public let id = "missing-redundancy"
    public let name = "Missing Redundancy"

    private static let criticalRoles: Set<NodeRole> = [.service, .database, .gateway, .loadBalancer, .firewall, .waf, .cache, .queue]
    private static let criticalValues: Set<String> = ["high", "critical"]

    public init() {}

    public func evaluate(_ page: DiagramPage) -> [ValidationIssue] {
        let roleGroups = Dictionary(grouping: page.nodes.values.filter { Self.criticalRoles.contains(NodeRole.of($0)) }) { NodeRole.of($0) }

        var issues: [ValidationIssue] = []
        for (_, nodes) in roleGroups where nodes.count == 1 {
            guard let node = nodes.first,
                  let criticality = node.metadata.criticality?.lowercased(),
                  Self.criticalValues.contains(criticality) else { continue }
            issues.append(ValidationIssue(
                ruleID: id,
                ruleName: name,
                severity: .warning,
                message: "\"\(ValidationSupport.displayName(node))\" is marked \(node.metadata.criticality ?? "critical") but has no redundant counterpart.",
                nodeIDs: [node.id]
            ))
        }
        return issues
    }
}
