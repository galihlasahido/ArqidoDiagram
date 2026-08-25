import Foundation
import DiagramModel

/// File-backed store for reusable saved-selection components — deliberately
/// app-wide (`~/Library/Application Support/ArqidoDiagram/`), not
/// per-document, so a component saved in one diagram can be reused in
/// another, matching how a personal shape library behaves in comparable
/// tools. A single JSON file is plenty at the scale a hand-curated
/// component library actually reaches; one file per component would only
/// add bookkeeping with no real benefit here.
public final class CustomComponentLibrary {
    private let fileURL: URL
    public private(set) var components: [CustomComponent] = []

    /// `directory` is injectable so tests can point this at a temp
    /// directory instead of the real Application Support folder.
    public init(directory: URL? = nil) {
        let baseDirectory = directory ?? CustomComponentLibrary.defaultDirectory()
        try? FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        fileURL = baseDirectory.appendingPathComponent("custom-components.json")
        load()
    }

    private static func defaultDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return appSupport.appendingPathComponent("ArqidoDiagram", isDirectory: true)
    }

    public func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            components = []
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        components = (try? decoder.decode([CustomComponent].self, from: data)) ?? []
    }

    @discardableResult
    public func save(_ component: CustomComponent) -> [CustomComponent] {
        components.removeAll { $0.id == component.id }
        components.append(component)
        persist()
        return components
    }

    @discardableResult
    public func delete(id: CustomComponentID) -> [CustomComponent] {
        components.removeAll { $0.id == id }
        persist()
        return components
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(components) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
