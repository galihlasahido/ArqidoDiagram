import Foundation

/// Seam reserved for Phase 2 ("Auto Layout"). No implementations yet.
public protocol LayoutEngine: Sendable {
    associatedtype Page
    func layout(_ page: Page) -> Page
}
