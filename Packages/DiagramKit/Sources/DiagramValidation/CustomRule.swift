import Foundation
import DiagramModel

/// The "Other user-defined rules" the spec calls for. One rule shape covers
/// a large share of real architecture rules ("every database must have a
/// firewall nearby", "no service may connect to a queue") without needing
/// a general expression language: does a node whose Type contains
/// `subjectType` have (or lack) an edge to some node whose Type contains
/// `relatedType`. `requireRelated = true` flags subjects *missing* the
/// relationship; `false` flags subjects that *have* it (a forbidden edge).
public struct CustomRule: Codable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var subjectType: String
    public var relatedType: String
    public var requireRelated: Bool
    public var severity: ValidationSeverity
    public var message: String

    public init(
        id: UUID = UUID(),
        name: String,
        subjectType: String,
        relatedType: String,
        requireRelated: Bool,
        severity: ValidationSeverity,
        message: String
    ) {
        self.id = id
        self.name = name
        self.subjectType = subjectType
        self.relatedType = relatedType
        self.requireRelated = requireRelated
        self.severity = severity
        self.message = message
    }
}

/// Adapts a `CustomRule` (plain data, so it can be saved to disk) to the
/// `ValidationRule` protocol `ValidationEngine` actually runs.
public struct CustomRuleEvaluator: ValidationRule {
    public let rule: CustomRule
    public var id: String { rule.id.uuidString }
    public var name: String { rule.name }

    public init(_ rule: CustomRule) {
        self.rule = rule
    }

    public func evaluate(_ page: DiagramPage) -> [ValidationIssue] {
        let subjectQuery = rule.subjectType.lowercased()
        let relatedQuery = rule.relatedType.lowercased()
        guard !subjectQuery.isEmpty, !relatedQuery.isEmpty else { return [] }

        let subjects = page.nodes.values.filter { matches($0, query: subjectQuery) }
        guard !subjects.isEmpty else { return [] }

        var neighborIDs: [NodeID: Set<NodeID>] = [:]
        for (_, a, b) in ValidationSupport.nodePairs(page) {
            neighborIDs[a.id, default: []].insert(b.id)
            neighborIDs[b.id, default: []].insert(a.id)
        }

        return subjects.compactMap { subject in
            let neighbors = (neighborIDs[subject.id] ?? []).compactMap { page.nodes[$0] }
            let hasRelated = neighbors.contains { matches($0, query: relatedQuery) }
            let violates = rule.requireRelated ? !hasRelated : hasRelated
            guard violates else { return nil }
            return ValidationIssue(
                ruleID: id,
                ruleName: rule.name,
                severity: rule.severity,
                message: rule.message.isEmpty
                    ? defaultMessage(for: subject)
                    : rule.message.replacingOccurrences(of: "{subject}", with: ValidationSupport.displayName(subject)),
                nodeIDs: [subject.id]
            )
        }
    }

    private func matches(_ node: DiagramNode, query: String) -> Bool {
        if let semantic = node.metadata.semanticType?.lowercased(), semantic.contains(query) { return true }
        return node.type.rawValue.lowercased().contains(query)
    }

    private func defaultMessage(for subject: DiagramNode) -> String {
        let relation = rule.requireRelated ? "has no connection to" : "should not connect to"
        return "\"\(ValidationSupport.displayName(subject))\" \(relation) a node of type \"\(rule.relatedType)\"."
    }
}
