import DiagramModel

/// Spec §21 "Documentation": generates real Markdown from diagram metadata
/// — deterministic and AI-free, so it works with zero configuration (the
/// spec's own worked example is reproduced almost verbatim per object).
/// `AIArchitect.writeDocumentation` (DiagramAI) can optionally produce
/// nicer prose *in addition* to this when AI is configured, but this
/// generator is what makes "Documentation" a real, always-available
/// feature rather than one gated behind AI setup.
public enum DocumentationGenerator {
    public static func markdown(title: String, pages: [DiagramPage]) -> String {
        var lines = ["# \(title)", ""]

        for page in pages {
            let nodes = page.nodeZOrder.compactMap { page.nodes[$0] }
            guard !nodes.isEmpty else { continue }
            if pages.count > 1 {
                lines.append("## \(page.name)")
                lines.append("")
            }
            for node in nodes {
                lines.append(contentsOf: section(for: node, headingLevel: pages.count > 1 ? 3 : 2))
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    /// Same content as `markdown(title:pages:)`, generated directly from
    /// the same node data rather than by parsing the Markdown text back —
    /// two independent renderers of one shared field list, so nothing can
    /// silently drift between the two formats.
    public static func html(title: String, pages: [DiagramPage]) -> String {
        var body = "<h1>\(escapeHTML(title))</h1>\n"
        for page in pages {
            let nodes = page.nodeZOrder.compactMap { page.nodes[$0] }
            guard !nodes.isEmpty else { continue }
            if pages.count > 1 {
                body += "<h2>\(escapeHTML(page.name))</h2>\n"
            }
            for node in nodes {
                body += htmlSection(for: node, headingTag: pages.count > 1 ? "h3" : "h2")
            }
        }
        return "<!DOCTYPE html>\n<html><head><meta charset=\"utf-8\"><title>\(escapeHTML(title))</title></head><body>\n\(body)</body></html>\n"
    }

    private static func htmlSection(for node: DiagramNode, headingTag: String) -> String {
        let label = node.text?.string.isEmpty == false ? node.text!.string : node.type.rawValue
        var html = "<\(headingTag)>\(escapeHTML(label))</\(headingTag)>\n<dl>\n"

        func field(_ name: String, _ value: String?) {
            guard let value, !value.isEmpty else { return }
            html += "<dt><strong>\(escapeHTML(name))</strong></dt><dd>\(escapeHTML(value))</dd>\n"
        }

        field("Type", node.metadata.semanticType)
        field("Technology", node.metadata.technology)
        field("Owner", node.metadata.owner)
        field("Environment", node.metadata.environment)
        field("Criticality", node.metadata.criticality)
        field("Description", node.metadata.notes)
        if !node.metadata.tags.isEmpty {
            field("Tags", node.metadata.tags.joined(separator: ", "))
        }
        html += "</dl>\n"
        return html
    }

    private static func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func section(for node: DiagramNode, headingLevel: Int) -> [String] {
        let label = node.text?.string.isEmpty == false ? node.text!.string : node.type.rawValue
        let heading = String(repeating: "#", count: headingLevel)
        var lines = ["\(heading) \(label)", ""]

        func field(_ name: String, _ value: String?) {
            guard let value, !value.isEmpty else { return }
            lines.append("**\(name):** \(value)")
            lines.append("")
        }

        field("Type", node.metadata.semanticType)
        field("Technology", node.metadata.technology)
        field("Owner", node.metadata.owner)
        field("Environment", node.metadata.environment)
        field("Criticality", node.metadata.criticality)
        field("Description", node.metadata.notes)
        if !node.metadata.tags.isEmpty {
            field("Tags", node.metadata.tags.joined(separator: ", "))
        }

        return lines
    }
}
