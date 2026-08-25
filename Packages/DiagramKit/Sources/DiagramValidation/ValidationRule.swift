import Foundation
import DiagramModel

public enum ValidationSeverity: String, Codable, Sendable, Comparable {
    case information, warning, error

    private var rank: Int {
        switch self {
        case .information: return 0
        case .warning: return 1
        case .error: return 2
        }
    }

    public static func < (lhs: ValidationSeverity, rhs: ValidationSeverity) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// One finding from a rule's `evaluate(_:)`. `nodeIDs`/`edgeIDs` are the
/// objects the finding is about — the Validation panel uses them to
/// select/jump to the offending object(s) on the canvas.
public struct ValidationIssue: Identifiable, Codable, Sendable {
    public let id: UUID
    public let ruleID: String
    public let ruleName: String
    public let severity: ValidationSeverity
    public let message: String
    public let nodeIDs: [NodeID]
    public let edgeIDs: [EdgeID]

    public init(
        id: UUID = UUID(),
        ruleID: String,
        ruleName: String,
        severity: ValidationSeverity,
        message: String,
        nodeIDs: [NodeID] = [],
        edgeIDs: [EdgeID] = []
    ) {
        self.id = id
        self.ruleID = ruleID
        self.ruleName = ruleName
        self.severity = severity
        self.message = message
        self.nodeIDs = nodeIDs
        self.edgeIDs = edgeIDs
    }
}

/// The canvas/UI layer only ever calls through this protocol (see
/// `ValidationEngine`) — it never contains rule logic itself, the same
/// "don't hard-code it into the UI" discipline the spec applies to layout
/// engines.
public protocol ValidationRule: Sendable {
    var id: String { get }
    var name: String { get }
    func evaluate(_ page: DiagramPage) -> [ValidationIssue]
}

/// Runs every built-in rule plus whatever custom rules the caller supplies,
/// sorted worst-first so the most severe findings surface at the top of the
/// Validation panel.
public enum ValidationEngine {
    public static let builtInRules: [any ValidationRule] = [
        PublicDatabaseRule(),
        MissingFirewallRule(),
        MissingWAFRule(),
        UnencryptedTrafficRule(),
        DirectServiceToDatabaseRule(),
        MissingRedundancyRule()
    ]

    public static func evaluate(_ page: DiagramPage, customRules: [any ValidationRule] = []) -> [ValidationIssue] {
        (builtInRules + customRules)
            .flatMap { $0.evaluate(page) }
            .sorted { $0.severity == $1.severity ? $0.message < $1.message : $0.severity > $1.severity }
    }
}
