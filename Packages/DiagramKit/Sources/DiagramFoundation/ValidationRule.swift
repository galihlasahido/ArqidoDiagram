import Foundation

/// Seam reserved for Phase 2 ("Architecture Validation"). No rules registered yet.
public enum ValidationSeverity: String, Codable, Sendable {
    case error, warning, information
}

public struct ValidationResult: Codable, Sendable {
    public let severity: ValidationSeverity
    public let message: String
    public let objectID: UUID?

    public init(severity: ValidationSeverity, message: String, objectID: UUID? = nil) {
        self.severity = severity
        self.message = message
        self.objectID = objectID
    }
}

public protocol ValidationRule: Sendable {
    associatedtype Page
    func evaluate(_ page: Page) -> [ValidationResult]
}
