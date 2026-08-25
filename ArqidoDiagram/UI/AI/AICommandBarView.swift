import SwiftUI
import DiagramModel
import DiagramAI

/// Spec §25 AI Command Bar (⌘K): "Prompt -> LLM -> Structured Diagram
/// Model -> Validation -> Layout Engine -> Native Diagram Objects."
/// Generated content is only ever *inserted*, never replaces or deletes
/// existing nodes — a deliberate safety choice ("AI should be an
/// assistant, not a replacement for the editor"), so a bad generation is
/// just a Cmd+Z away rather than destructive.
struct AICommandBarView: View {
    @ObservedObject var document: DiagramDocument
    @ObservedObject var commandBarModel: AICommandBarModel
    @ObservedObject var configStore: AIConfigurationStore
    @ObservedObject var bridge: InspectorBridge
    @Binding var activePageID: PageID?

    @State private var prompt = ""
    @State private var isLoading = false
    @State private var resultText: String?
    @State private var errorMessage: String?
    @State private var showingSettings = false

    private static let quickActions: [(label: String, prompt: String)] = [
        ("Generate architecture", "Create an architecture using an API Gateway, a service, and a database."),
        ("Generate ERD", "Generate an ERD for a simple e-commerce database with customers, orders, and products."),
        ("Explain diagram", "Explain this diagram."),
        ("Improve layout", "Improve the layout."),
        ("Simplify diagram", "Simplify this diagram."),
        ("Find architecture problems", "Find architecture problems.")
    ]

    private var currentPage: DiagramPage? {
        let pageID = activePageID ?? document.model.pageOrder.first
        return pageID.flatMap { document.model.pages[$0] }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            promptField
            if !configStore.isConfigured {
                unconfiguredNotice
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
            }
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(10)
            }
            if let resultText {
                Divider()
                ScrollView {
                    Text(resultText)
                        .font(.callout)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(maxHeight: 260)
            }
            if resultText == nil, !isLoading {
                Divider()
                quickActionsList
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor)))
        .shadow(radius: 8)
        .frame(width: 460)
        .sheet(isPresented: $showingSettings) {
            AISettingsView(configStore: configStore)
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundStyle(.secondary)
            Text("AI Command Bar")
                .font(.callout.weight(.semibold))
            Spacer()
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("AI Settings…")
            Button {
                commandBarModel.isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(8)
    }

    private var promptField: some View {
        HStack {
            TextField("Ask AI to generate, explain, or improve this diagram…", text: $prompt, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .onSubmit { submit() }
            Button("Go") { submit() }
                .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
        .padding(10)
    }

    private var unconfiguredNotice: some View {
        HStack {
            Text("AI isn't configured — \"Improve Layout\" and \"Find Problems\" still work without it.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Configure…") { showingSettings = true }
                .buttonStyle(.link)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }

    private var quickActionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Self.quickActions, id: \.label) { action in
                Button {
                    prompt = action.prompt
                    submit()
                } label: {
                    Text(action.label)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func submit() {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        errorMessage = nil
        resultText = nil

        switch AICommandIntent.classify(text) {
        case .improveLayout:
            bridge.canvasView?.applyHierarchicalLayout(nil)
            commandBarModel.isPresented = false
        case .findProblems:
            commandBarModel.isPresented = false
            NotificationCenter.default.post(name: .toggleValidation, object: nil)
        case .explain, .generateDocumentation, .reviseExisting, .generateNew:
            guard let provider = configStore.provider else {
                errorMessage = "AI isn't configured yet. Click the gear icon to choose Local or External."
                return
            }
            runAI(text: text, provider: provider)
        }
    }

    private func runAI(text: String, provider: any AIProvider) {
        isLoading = true
        let architect = AIArchitect(provider: provider)
        let page = currentPage ?? DiagramPage(name: "", order: 0)
        let intent = AICommandIntent.classify(text)

        Task {
            do {
                switch intent {
                case .explain:
                    let text = try await architect.explain(summary: AIDiagramSummary.summarize(page))
                    await MainActor.run { resultText = text; isLoading = false }
                case .generateDocumentation:
                    let text = try await architect.writeDocumentation(summary: AIDiagramSummary.summarize(page))
                    await MainActor.run { resultText = text; isLoading = false }
                case .reviseExisting(let instruction):
                    let fullPrompt = "Current diagram:\n\(AIDiagramSummary.summarize(page))\n\nInstruction: \(instruction)\n\nRespond with a diagram reflecting this instruction."
                    let result = try await architect.generateDiagram(prompt: fullPrompt)
                    await MainActor.run {
                        bridge.canvasView?.insertGeneratedNodes(result.nodes, edges: result.edges)
                        isLoading = false
                        commandBarModel.isPresented = false
                    }
                case .generateNew(let userPrompt):
                    let result = try await architect.generateDiagram(prompt: userPrompt)
                    await MainActor.run {
                        bridge.canvasView?.insertGeneratedNodes(result.nodes, edges: result.edges)
                        isLoading = false
                        commandBarModel.isPresented = false
                    }
                case .improveLayout, .findProblems:
                    break
                }
            } catch {
                await MainActor.run {
                    errorMessage = describeError(error)
                    isLoading = false
                }
            }
        }
    }

    private func describeError(_ error: Error) -> String {
        switch error {
        case AIProviderError.notConfigured: return "AI isn't configured."
        case AIProviderError.requestFailed(let message): return "Request failed: \(message)"
        case AIProviderError.invalidResponse: return "The AI provider returned an unreadable response."
        case AIProviderError.emptyCompletion: return "The AI provider returned an empty response."
        case AIArchitectError.couldNotParseResponse: return "The AI's response wasn't valid diagram JSON. Try rephrasing."
        default: return "\(error)"
        }
    }
}
