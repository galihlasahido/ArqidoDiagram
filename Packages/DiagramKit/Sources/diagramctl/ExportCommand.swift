import Foundation
import ArgumentParser
import DiagramModel
import DiagramExport
import DiagramInterop

/// `diagramctl export architecture.diagram --format pdf|svg|png|mermaid|
/// plantuml|dot|yaml|sql|markdown|html` (spec §34's example plus every
/// format §23/§28 call for). Image formats (PNG/PDF/SVG) are async —
/// `DiagramExport`'s adapters already are — so this is the one
/// `AsyncParsableCommand` in the tree; the root command picks that up
/// automatically.
struct ExportCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "export",
        abstract: "Export a .diagram package's page to PNG, PDF, SVG, Mermaid, PlantUML, Graphviz DOT, Architecture YAML, SQL, Markdown, or HTML."
    )

    @Argument(help: "Path to the .diagram package.")
    var input: String

    @Option(name: .shortAndLong, help: "png, pdf, svg, mermaid, plantuml, dot, yaml, sql, markdown, or html.")
    var format: String

    @Option(name: .shortAndLong, help: "Output file path (default: <input>.<format>).")
    var output: String?

    @Option(name: .long, help: "Page name to export (default: the first page).")
    var page: String?

    func run() async throws {
        let model = try PackageIO.read(from: input)
        let pages = model.pageOrder.compactMap { model.pages[$0] }
        guard !pages.isEmpty else { throw ValidationError("\(input) has no pages.") }

        let targetPage: DiagramPage
        if let pageName = page {
            guard let found = pages.first(where: { $0.name == pageName }) else {
                throw ValidationError("No page named \"\(pageName)\" — available pages: \(pages.map(\.name).joined(separator: ", "))")
            }
            targetPage = found
        } else {
            targetPage = pages[0]
        }

        let lowercasedFormat = format.lowercased()
        let outputPath = output ?? defaultOutputPath(for: input, format: lowercasedFormat)
        let outputURL = URL(fileURLWithPath: outputPath)

        switch lowercasedFormat {
        case "png":
            try await PNGExportAdapter.write(targetPage, to: outputURL)
        case "pdf":
            try await PDFExportAdapter.write(targetPage, to: outputURL)
        case "svg":
            try await SVGExportAdapter.write(targetPage, to: outputURL)
        case "mermaid":
            try MermaidExporter.export(targetPage).write(to: outputURL, atomically: true, encoding: .utf8)
        case "plantuml":
            try PlantUMLExporter.export(targetPage).write(to: outputURL, atomically: true, encoding: .utf8)
        case "dot":
            try GraphvizExporter.export(targetPage, name: model.title).write(to: outputURL, atomically: true, encoding: .utf8)
        case "yaml":
            try ArchitectureYAMLExporter.export(targetPage, architectureName: model.title).write(to: outputURL, atomically: true, encoding: .utf8)
        case "sql":
            try SQLExporter.export(targetPage).write(to: outputURL, atomically: true, encoding: .utf8)
        case "markdown":
            try DocumentationGenerator.markdown(title: model.title, pages: pages).write(to: outputURL, atomically: true, encoding: .utf8)
        case "html":
            try DocumentationGenerator.html(title: model.title, pages: pages).write(to: outputURL, atomically: true, encoding: .utf8)
        default:
            throw ValidationError("Unknown format \"\(format)\". Supported: png, pdf, svg, mermaid, plantuml, dot, yaml, sql, markdown, html.")
        }
        print("Wrote \(outputPath)")
    }

    private func defaultOutputPath(for input: String, format: String) -> String {
        let base = (input as NSString).deletingPathExtension
        let extensionByFormat = ["mermaid": "mmd", "plantuml": "puml", "dot": "dot", "yaml": "yaml", "sql": "sql", "markdown": "md", "html": "html"]
        return "\(base).\(extensionByFormat[format] ?? format)"
    }
}
