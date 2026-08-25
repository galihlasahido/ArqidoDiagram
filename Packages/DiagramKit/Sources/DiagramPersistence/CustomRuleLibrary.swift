import Foundation
import DiagramValidation

/// File-backed store for user-defined `CustomRule`s — app-wide, same
/// rationale as `CustomComponentLibrary`: a validation rule someone writes
/// ("every database needs a firewall") is just as reusable across documents
/// as a saved shape selection.
public final class CustomRuleLibrary {
    private let fileURL: URL
    public private(set) var rules: [CustomRule] = []

    public init(directory: URL? = nil) {
        let baseDirectory = directory ?? CustomRuleLibrary.defaultDirectory()
        try? FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        fileURL = baseDirectory.appendingPathComponent("custom-validation-rules.json")
        load()
    }

    private static func defaultDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return appSupport.appendingPathComponent("ArqidoDiagram", isDirectory: true)
    }

    public func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            rules = []
            return
        }
        rules = (try? JSONDecoder().decode([CustomRule].self, from: data)) ?? []
    }

    @discardableResult
    public func save(_ rule: CustomRule) -> [CustomRule] {
        rules.removeAll { $0.id == rule.id }
        rules.append(rule)
        persist()
        return rules
    }

    @discardableResult
    public func delete(id: UUID) -> [CustomRule] {
        rules.removeAll { $0.id == id }
        persist()
        return rules
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        guard let data = try? encoder.encode(rules) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
