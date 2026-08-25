import Foundation

/// Spec §20 "Architecture Decision Records": "Allow documents to contain
/// ADRs... ADRs should link to diagram objects." `linkedNodeIDs` is that
/// link — deliberately by ID (not by label), so it survives a node being
/// renamed without going stale.
public enum ADRStatus: String, Codable, Sendable, CaseIterable {
    case proposed, accepted, rejected, deprecated, superseded

    public var displayName: String { rawValue.capitalized }
}

public struct ArchitectureDecisionRecord: Codable, Identifiable, Sendable {
    public let id: UUID
    /// The sequential "ADR-001" number — assigned once at creation
    /// (`ADRStore.nextNumber`), never renumbered, so an ID printed in a
    /// commit message or another ADR's text always still refers to the
    /// same record.
    public var number: Int
    public var title: String
    public var status: ADRStatus
    public var context: String
    public var decision: String
    /// Free-text lines, conventionally prefixed "+"/"-" per the spec's own
    /// example ("+ High throughput", "- Operational complexity").
    public var consequences: [String]
    public var linkedNodeIDs: [NodeID]
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        number: Int,
        title: String,
        status: ADRStatus = .proposed,
        context: String = "",
        decision: String = "",
        consequences: [String] = [],
        linkedNodeIDs: [NodeID] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.number = number
        self.title = title
        self.status = status
        self.context = context
        self.decision = decision
        self.consequences = consequences
        self.linkedNodeIDs = linkedNodeIDs
        self.createdAt = createdAt
    }

    /// Matches the spec's own worked example layout exactly.
    public var markdown: String {
        var lines = ["ADR-\(String(format: "%03d", number))", "", "Title:", title, "", "Status:", status.displayName]
        if !context.isEmpty { lines += ["", "Context:", context] }
        if !decision.isEmpty { lines += ["", "Decision:", decision] }
        if !consequences.isEmpty { lines += ["", "Consequences:"] + consequences }
        return lines.joined(separator: "\n")
    }
}
