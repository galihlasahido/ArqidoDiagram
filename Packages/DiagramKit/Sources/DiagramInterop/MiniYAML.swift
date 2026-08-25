import Foundation

/// A parser for standard block-style YAML — mappings, sequences, scalars,
/// comments — which is what virtually every real-world Kubernetes
/// manifest, OpenAPI document, docker-compose file, and this app's own
/// Architecture-as-Code YAML actually use. Deliberately does not handle
/// flow-style `{...}`/`[...]` collections, anchors/aliases, or multiline
/// block scalars (`|`/`>`) — a full YAML 1.2 implementation is a large
/// undertaking for value this app doesn't need; the documented subset
/// covers every importer this module ships.
public indirect enum YAMLValue {
    case scalar(String)
    case sequence([YAMLValue])
    case mapping([(key: String, value: YAMLValue)])

    public var stringValue: String? {
        if case .scalar(let value) = self { return value }
        return nil
    }

    public var arrayValue: [YAMLValue]? {
        if case .sequence(let values) = self { return values }
        return nil
    }

    public subscript(key: String) -> YAMLValue? {
        guard case .mapping(let pairs) = self else { return nil }
        return pairs.first { $0.key == key }?.value
    }
}

public enum MiniYAML {
    private struct Line {
        let indent: Int
        let content: String
    }

    /// Parses only the first `---`-separated document — every format this
    /// module imports uses a single document per file (Kubernetes multi-
    /// document manifests are handled by `KubernetesImporter` splitting on
    /// `---` itself before calling this, so each call sees one document).
    public static func parse(_ text: String) -> YAMLValue {
        let lines = preprocess(text)
        guard !lines.isEmpty else { return .mapping([]) }
        var index = 0
        return parseBlock(lines, &index, minIndent: lines[0].indent)
    }

    private static func preprocess(_ text: String) -> [Line] {
        var result: [Line] = []
        for rawLine in text.components(separatedBy: "\n") {
            let stripped = stripComment(rawLine)
            let trimmed = stripped.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, trimmed != "---" else { continue }
            let indent = stripped.prefix(while: { $0 == " " }).count
            result.append(Line(indent: indent, content: String(stripped.dropFirst(indent))))
        }
        return result
    }

    private static func stripComment(_ line: String) -> String {
        var inSingleQuote = false
        var inDoubleQuote = false
        for index in line.indices {
            let character = line[index]
            if character == "'" && !inDoubleQuote { inSingleQuote.toggle() }
            if character == "\"" && !inSingleQuote { inDoubleQuote.toggle() }
            if character == "#" && !inSingleQuote && !inDoubleQuote {
                // A `#` only starts a comment when preceded by whitespace
                // or at line start — "http://x#frag" style values are rare
                // here, but this keeps `key: "a#b"` safe regardless.
                if index == line.startIndex || line[line.index(before: index)] == " " {
                    return String(line[line.startIndex..<index])
                }
            }
        }
        return line
    }

    private static func parseBlock(_ lines: [Line], _ index: inout Int, minIndent: Int) -> YAMLValue {
        guard index < lines.count, lines[index].indent == minIndent else { return .mapping([]) }
        if isSequenceLine(lines[index].content) {
            return parseSequence(lines, &index, indent: minIndent)
        }
        return parseMapping(lines, &index, indent: minIndent)
    }

    private static func isSequenceLine(_ content: String) -> Bool {
        content == "-" || content.hasPrefix("- ")
    }

    private static func parseSequence(_ lines: [Line], _ index: inout Int, indent: Int) -> YAMLValue {
        var items: [YAMLValue] = []
        while index < lines.count, lines[index].indent == indent, isSequenceLine(lines[index].content) {
            let content = lines[index].content
            let afterDash = content == "-" ? "" : String(content.dropFirst(2))
            let dashWidth = content.count - afterDash.count

            if afterDash.isEmpty {
                index += 1
                if index < lines.count, lines[index].indent > indent {
                    items.append(parseBlock(lines, &index, minIndent: lines[index].indent))
                } else {
                    items.append(.scalar(""))
                }
            } else if findKeyColon(in: afterDash) != nil {
                // "- key: value" begins an inline mapping; its own key/value
                // sits at a virtual indent right after the dash, and any
                // further-indented following lines continue that mapping.
                let virtualIndent = indent + dashWidth
                var syntheticLines = [Line(indent: virtualIndent, content: afterDash)]
                index += 1
                while index < lines.count, lines[index].indent >= virtualIndent {
                    syntheticLines.append(lines[index])
                    index += 1
                }
                var subIndex = 0
                items.append(parseBlock(syntheticLines, &subIndex, minIndent: virtualIndent))
            } else {
                items.append(.scalar(unquote(afterDash)))
                index += 1
            }
        }
        return .sequence(items)
    }

    private static func parseMapping(_ lines: [Line], _ index: inout Int, indent: Int) -> YAMLValue {
        var pairs: [(String, YAMLValue)] = []
        while index < lines.count, lines[index].indent == indent, !isSequenceLine(lines[index].content) {
            let content = lines[index].content
            guard let colonIndex = findKeyColon(in: content) else {
                index += 1
                continue
            }
            let key = unquote(String(content[content.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces))
            let restStart = content.index(after: colonIndex)
            let rest = String(content[restStart...]).trimmingCharacters(in: .whitespaces)
            index += 1

            if rest.isEmpty {
                if index < lines.count, lines[index].indent > indent {
                    pairs.append((key, parseBlock(lines, &index, minIndent: lines[index].indent)))
                } else {
                    pairs.append((key, .scalar("")))
                }
            } else {
                pairs.append((key, .scalar(unquote(rest))))
            }
        }
        return .mapping(pairs)
    }

    /// The first top-level `:` — one not inside a quoted string — which is
    /// what separates a mapping key from its value.
    private static func findKeyColon(in text: String) -> String.Index? {
        var inSingleQuote = false
        var inDoubleQuote = false
        for index in text.indices {
            let character = text[index]
            if character == "'" && !inDoubleQuote { inSingleQuote.toggle() }
            if character == "\"" && !inSingleQuote { inDoubleQuote.toggle() }
            if character == ":" && !inSingleQuote && !inDoubleQuote {
                let next = text.index(after: index)
                if next == text.endIndex || text[next] == " " {
                    return index
                }
            }
        }
        return nil
    }

    private static func unquote(_ value: String) -> String {
        guard value.count >= 2 else { return value }
        if value.hasPrefix("\"") && value.hasSuffix("\"") {
            return String(value.dropFirst().dropLast())
        }
        if value.hasPrefix("'") && value.hasSuffix("'") {
            return String(value.dropFirst().dropLast())
        }
        return value
    }
}
