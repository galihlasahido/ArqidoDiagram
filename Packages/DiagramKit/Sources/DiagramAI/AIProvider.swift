import Foundation

public enum AIProviderError: Error, Sendable {
    case notConfigured
    case invalidResponse
    case requestFailed(String)
    case emptyCompletion
}

/// "AI should be an assistant, not a replacement for the editor" — this
/// protocol is deliberately narrow (one text-completion method). Every
/// higher-level behavior (generate a diagram, explain a diagram, write
/// documentation) is built in `AIArchitect` on top of this single seam, so
/// swapping backends never touches prompt/parsing logic.
public protocol AIProvider: Sendable {
    var displayName: String { get }
    func complete(system: String, user: String, maxTokens: Int) async throws -> String
}
