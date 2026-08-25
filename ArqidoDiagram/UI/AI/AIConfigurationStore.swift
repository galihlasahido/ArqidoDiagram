import Foundation
import DiagramAI

/// Spec §26/§SECURITY: AI defaults to off. Local (Ollama) is the
/// recommended, no-network-request mode; External requires the user to
/// explicitly enter a base URL/model and (separately, via Keychain) an API
/// key — there is no bundled default endpoint or key.
final class AIConfigurationStore: ObservableObject {
    enum Mode: String {
        case off
        case local
        case external
    }

    @Published var mode: Mode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Keys.mode) }
    }
    @Published var localBaseURL: String {
        didSet { UserDefaults.standard.set(localBaseURL, forKey: Keys.localBaseURL) }
    }
    @Published var localModel: String {
        didSet { UserDefaults.standard.set(localModel, forKey: Keys.localModel) }
    }
    @Published var externalBaseURL: String {
        didSet { UserDefaults.standard.set(externalBaseURL, forKey: Keys.externalBaseURL) }
    }
    @Published var externalModel: String {
        didSet { UserDefaults.standard.set(externalModel, forKey: Keys.externalModel) }
    }
    @Published private(set) var hasExternalKey: Bool

    private enum Keys {
        static let mode = "ai.mode"
        static let localBaseURL = "ai.local.baseURL"
        static let localModel = "ai.local.model"
        static let externalBaseURL = "ai.external.baseURL"
        static let externalModel = "ai.external.model"
    }

    init() {
        let defaults = UserDefaults.standard
        mode = Mode(rawValue: defaults.string(forKey: Keys.mode) ?? "") ?? .off
        localBaseURL = defaults.string(forKey: Keys.localBaseURL) ?? "http://localhost:11434"
        localModel = defaults.string(forKey: Keys.localModel) ?? "llama3.1"
        externalBaseURL = defaults.string(forKey: Keys.externalBaseURL) ?? ""
        externalModel = defaults.string(forKey: Keys.externalModel) ?? ""
        hasExternalKey = AIKeychain.load() != nil
    }

    func setExternalKey(_ key: String) {
        AIKeychain.save(key)
        hasExternalKey = true
    }

    func clearExternalKey() {
        AIKeychain.clear()
        hasExternalKey = false
    }

    /// `nil` when AI is off, or when External is selected but not fully
    /// configured yet — callers show a real disabled state rather than
    /// attempting a request that can only fail.
    var provider: (any AIProvider)? {
        switch mode {
        case .off:
            return nil
        case .local:
            guard let url = URL(string: localBaseURL), !localModel.isEmpty else { return nil }
            return OllamaAIProvider(baseURL: url, model: localModel)
        case .external:
            guard let url = URL(string: externalBaseURL), !externalModel.isEmpty, let key = AIKeychain.load(), !key.isEmpty else { return nil }
            return RemoteAIProvider(baseURL: url, apiKey: key, model: externalModel)
        }
    }

    var isConfigured: Bool { provider != nil }
}
