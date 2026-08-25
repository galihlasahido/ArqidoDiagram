import Foundation

/// Seam reserved for Phase 3 ("Code Import" — SQL, OpenAPI, Docker Compose,
/// Kubernetes YAML, Terraform). No implementations, no UI entry point yet.
public protocol ImportAdapter: Sendable {
    associatedtype DocumentModel
    func importFile(at url: URL) throws -> DocumentModel
}
