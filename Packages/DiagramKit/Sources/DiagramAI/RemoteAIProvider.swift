import Foundation

/// Spec §SECURITY "Explicit external AI configuration": this backend is
/// never reached unless the user has explicitly entered a base URL, API
/// key, and model in Settings — there is no default/bundled endpoint.
/// Speaks the OpenAI-compatible `/chat/completions` shape, which is what
/// the overwhelming majority of hosted-model gateways (including
/// self-hosted ones) implement.
public struct RemoteAIProvider: AIProvider {
    public let displayName: String
    private let baseURL: URL
    private let apiKey: String
    private let model: String
    private let session: URLSession

    public init(baseURL: URL, apiKey: String, model: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.session = session
        self.displayName = "External (\(model))"
    }

    private struct ChatMessage: Encodable {
        let role: String
        let content: String
    }

    private struct ChatRequest: Encodable {
        let model: String
        let messages: [ChatMessage]
        let max_tokens: Int
        let temperature: Double
    }

    private struct ChatChoice: Decodable {
        struct Message: Decodable { let content: String? }
        let message: Message
    }

    private struct ChatResponse: Decodable {
        let choices: [ChatChoice]
    }

    public func complete(system: String, user: String, maxTokens: Int) async throws -> String {
        var url = baseURL
        if !url.path.hasSuffix("/chat/completions") {
            url = url.appendingPathComponent("chat/completions")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let body = ChatRequest(
            model: model,
            messages: [
                ChatMessage(role: "system", content: system),
                ChatMessage(role: "user", content: user)
            ],
            // Some gateways bill "reasoning" tokens against the same
            // max_tokens budget as the visible answer, so a low cap can
            // truncate the response to nothing before it writes a single
            // visible character — the cap here is generous for exactly
            // that reason, not because the answers themselves are long.
            max_tokens: max(maxTokens, 2000),
            temperature: 0.2
        )
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AIProviderError.requestFailed(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw AIProviderError.requestFailed("HTTP \(status)")
        }

        guard let jsonData = JSONExtraction.firstJSONObject(in: data) else {
            throw AIProviderError.invalidResponse
        }
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: jsonData)
        guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
            throw AIProviderError.emptyCompletion
        }
        return content
    }
}
