import Foundation

/// Open key-value bag per spec §17/§Inspector — Phase 1 UI edits this via a
/// generic key-value form. Well-known keys get typed convenience accessors
/// so later phases (validation engine, documentation generation) don't
/// re-parse free-text strings.
public struct Metadata: Codable, Hashable, Sendable {
    public var fields: [String: String]
    public var tags: [String]

    /// Reserved for Phase 2+ ("Architecture Intelligence", e.g. "service",
    /// "database", "gateway"). Unused by Phase 1 UI beyond free text.
    public var semanticType: String?

    public init(fields: [String: String] = [:], tags: [String] = [], semanticType: String? = nil) {
        self.fields = fields
        self.tags = tags
        self.semanticType = semanticType
    }

    private static let technologyKey = "technology"
    private static let ownerKey = "owner"
    private static let environmentKey = "environment"
    private static let criticalityKey = "criticality"
    private static let descriptionKey = "description"

    public var technology: String? {
        get { fields[Self.technologyKey] }
        set { fields[Self.technologyKey] = newValue }
    }

    public var owner: String? {
        get { fields[Self.ownerKey] }
        set { fields[Self.ownerKey] = newValue }
    }

    public var environment: String? {
        get { fields[Self.environmentKey] }
        set { fields[Self.environmentKey] = newValue }
    }

    public var criticality: String? {
        get { fields[Self.criticalityKey] }
        set { fields[Self.criticalityKey] = newValue }
    }

    public var notes: String? {
        get { fields[Self.descriptionKey] }
        set { fields[Self.descriptionKey] = newValue }
    }
}
