import Foundation
import ArgumentParser
import DiagramInterop

/// `diagramctl document architecture.diagram` (spec §21/§34 "Automated
/// documentation").
struct DocumentCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "document",
        abstract: "Generate Markdown or HTML documentation from a .diagram package's metadata."
    )

    @Argument(help: "Path to the .diagram package.")
    var input: String

    @Option(name: .shortAndLong, help: "markdown or html.")
    var format: String = "markdown"

    @Option(name: .shortAndLong, help: "Output file path (default: <input>.md / .html).")
    var output: String?

    func run() throws {
        let model = try PackageIO.read(from: input)
        let pages = model.pageOrder.compactMap { model.pages[$0] }

        let text: String
        let ext: String
        switch format.lowercased() {
        case "markdown", "md":
            text = DocumentationGenerator.markdown(title: model.title, pages: pages)
            ext = "md"
        case "html":
            text = DocumentationGenerator.html(title: model.title, pages: pages)
            ext = "html"
        default:
            throw ValidationError("Unknown format \"\(format)\". Supported: markdown, html.")
        }

        let outputPath = output ?? (input as NSString).deletingPathExtension + "." + ext
        try text.write(toFile: outputPath, atomically: true, encoding: .utf8)
        print("Wrote \(outputPath)")
    }
}
