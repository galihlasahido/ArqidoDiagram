import SwiftUI

/// Spec §SECURITY "Explicit external AI configuration" + §26 "Local AI":
/// AI defaults to Off. Local (Ollama-compatible) never sends diagram
/// content anywhere but this machine; switching to External is a
/// deliberate, separate choice, and its API key lives only in the
/// Keychain — never in a document, never in this app's own defaults file.
struct AISettingsView: View {
    @ObservedObject var configStore: AIConfigurationStore
    @Environment(\.dismiss) private var dismiss

    @State private var apiKeyField = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Settings")
                .font(.headline)

            Picker("Mode", selection: $configStore.mode) {
                Text("Off").tag(AIConfigurationStore.Mode.off)
                Text("Local (Ollama)").tag(AIConfigurationStore.Mode.local)
                Text("External").tag(AIConfigurationStore.Mode.external)
            }
            .pickerStyle(.segmented)

            switch configStore.mode {
            case .off:
                Text("AI features are disabled. Diagram content never leaves this computer.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            case .local:
                localForm
            case .external:
                externalForm
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private var localForm: some View {
        Form {
            TextField("Server URL", text: $configStore.localBaseURL)
            TextField("Model", text: $configStore.localModel)
            Text("No diagram data leaves this computer in Local mode — requests go only to the server above, which defaults to Ollama's own local address.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var externalForm: some View {
        Form {
            TextField("Base URL", text: $configStore.externalBaseURL)
                .textContentType(.URL)
            TextField("Model", text: $configStore.externalModel)

            if configStore.hasExternalKey {
                HStack {
                    Label("API key saved in Keychain", systemImage: "checkmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.green)
                    Spacer()
                    Button("Remove") { configStore.clearExternalKey() }
                        .buttonStyle(.link)
                }
            } else {
                HStack {
                    SecureField("API Key", text: $apiKeyField)
                    Button("Save") {
                        guard !apiKeyField.isEmpty else { return }
                        configStore.setExternalKey(apiKeyField)
                        apiKeyField = ""
                    }
                    .disabled(apiKeyField.isEmpty)
                }
            }

            Text("Diagram content and prompts are sent to this endpoint when External mode is active.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
