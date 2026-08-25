import Foundation
import DiagramModel

/// Classifies a free-text ⌘K command into one of the spec's example
/// intents (§25: generate/explain/improve layout/simplify/find problems/
/// add missing/convert/generate documentation). Two of these — "Improve
/// Layout" and "Find architecture problems" — route to the *existing*
/// LayoutEngine/ValidationEngine and never touch an AIProvider at all,
/// which is exactly "AI should be an assistant, not a replacement for the
/// editor": those features already exist and work without AI.
enum AICommandIntent {
    case improveLayout
    case findProblems
    case explain
    case generateDocumentation
    case reviseExisting(instruction: String)
    case generateNew(prompt: String)

    static func classify(_ text: String) -> AICommandIntent {
        let lowered = text.lowercased()
        if lowered.contains("layout") { return .improveLayout }
        if lowered.contains("problem") || lowered.contains("issue") || lowered.contains("valida") { return .findProblems }
        if lowered.contains("explain") { return .explain }
        if lowered.contains("document") { return .generateDocumentation }
        if lowered.contains("simplify") || lowered.contains("missing") || lowered.contains("convert") {
            return .reviseExisting(instruction: text)
        }
        return .generateNew(prompt: text)
    }
}

enum AIDiagramSummary {
    /// A compact, token-cheap description of a page's current contents —
    /// enough for the model to reason about what already exists (for
    /// Explain/Simplify/Add Missing/Document) without re-sending the full
    /// geometry it doesn't need.
    static func summarize(_ page: DiagramPage) -> String {
        guard !page.nodes.isEmpty else { return "The diagram is currently empty." }

        let nodeLines = page.nodeZOrder.compactMap { page.nodes[$0] }.map { node -> String in
            let label = node.text?.string.isEmpty == false ? node.text!.string : node.type.rawValue
            let type = node.metadata.semanticType ?? node.type.rawValue
            return "- \(label) (type: \(type))"
        }
        let edgeLines = page.edgeZOrder.compactMap { page.edges[$0] }.compactMap { edge -> String? in
            guard case .node(let sourceID, _) = edge.source, case .node(let targetID, _) = edge.target,
                  let source = page.nodes[sourceID], let target = page.nodes[targetID] else { return nil }
            let sourceLabel = source.text?.string.isEmpty == false ? source.text!.string : source.type.rawValue
            let targetLabel = target.text?.string.isEmpty == false ? target.text!.string : target.type.rawValue
            return "- \(sourceLabel) -> \(targetLabel)"
        }

        var summary = "Components:\n" + nodeLines.joined(separator: "\n")
        if !edgeLines.isEmpty {
            summary += "\n\nConnections:\n" + edgeLines.joined(separator: "\n")
        }
        return summary
    }
}
