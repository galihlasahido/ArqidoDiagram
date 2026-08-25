import Foundation

/// Spec §26 "Local AI": talks only to a model server on this machine
/// (Ollama's default `http://localhost:11434`, or another Ollama-API-
/// compatible local runtime) — no diagram content is ever sent anywhere
/// else. This is the default/recommended provider; `RemoteAIProvider` is
/// the explicit opt-in.
public struct OllamaAIProvider: AIProvider {
    public let displayName: String
    private let baseURL: URL
    private let model: String
    private let session: URLSession

    public init(baseURL: URL = URL(string: "http://localhost:11434")!, model: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.model = model
        self.session = session
        self.displayName = "Local (\(model))"
    }

    private struct ChatMessage: Encodable {
        let role: String
        let content: String
    }

    private struct ChatRequest: Encodable {
        let model: String
        let messages: [ChatMessage]
        let stream: Bool
    }

    private struct ChatResponse: Decodable {
        struct Message: Decodable { let content: String }
        let message: Message
    }

    public func complete(system: String, user: String, maxTokens: Int) async throws -> String {
        let url = baseURL.appendingPathComponent("api/chat")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ChatRequest(
            model: model,
            messages: [
                ChatMessage(role: "system", content: system),
                ChatMessage(role: "user", content: user)
            ],
            stream: false
        )
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AIProviderError.requestFailed("Couldn't reach the local model server at \(baseURL.absoluteString) — is Ollama running? (\(error.localizedDescription))")
        }

        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw AIProviderError.requestFailed("Local model server returned HTTP \(status)")
        }

        guard let jsonData = JSONExtraction.firstJSONObject(in: data) else {
            throw AIProviderError.invalidResponse
        }
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: jsonData)
        guard !decoded.message.content.isEmpty else {
            throw AIProviderError.emptyCompletion
        }
        return decoded.message.content
    }
}
