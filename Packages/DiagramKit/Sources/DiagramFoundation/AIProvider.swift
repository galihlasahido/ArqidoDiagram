import Foundation

/// Seam reserved for Phase 3 ("AI"). No implementations yet. The app target's
/// AI command bar (⌘K) surfaces as a real, visibly-disabled menu item with a
/// tooltip explaining it's not available yet — not hidden, not faked.
public protocol AIProvider: Sendable {
    associatedtype DocumentModel
    func generate(prompt: String) async throws -> DocumentModel
}
