import Foundation

enum JSONExtraction {
    /// Some OpenAI-compatible proxies append a trailing SSE terminator
    /// (`data: [DONE]`) even to a non-streaming response body, which makes
    /// the whole payload invalid JSON even though the actual object is
    /// well-formed. Scans for the first balanced top-level `{...}` (brace
    /// depth, ignoring braces inside string literals) and decodes just
    /// that, rather than trusting the response to be nothing but JSON.
    static func firstJSONObject(in data: Data) -> Data? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        return firstJSONObject(in: text).flatMap { $0.data(using: .utf8) }
    }

    static func firstJSONObject(in text: String) -> String? {
        guard let start = text.firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var isEscaped = false
        var index = start

        while index < text.endIndex {
            let character = text[index]
            if inString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    inString = false
                }
            } else {
                switch character {
                case "\"": inString = true
                case "{": depth += 1
                case "}":
                    depth -= 1
                    if depth == 0 {
                        return String(text[start...index])
                    }
                default: break
                }
            }
            index = text.index(after: index)
        }
        return nil
    }
}
