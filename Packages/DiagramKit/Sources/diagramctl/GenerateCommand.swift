import Foundation
import ArgumentParser
import DiagramModel
import DiagramLayout
import DiagramInterop

/// `diagramctl generate architecture.yaml` (spec §34).
struct GenerateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "generate",
        abstract: "Generate a .diagram package from an Architecture-as-Code YAML file (spec §24)."
    )

    @Argument(help: "Path to the Architecture-as-Code YAML file.")
    var input: String

    @Option(name: .shortAndLong, help: "Output .diagram package path (default: <input>.diagram).")
    var output: String?

    func run() throws {
        let yaml = try String(contentsOfFile: input, encoding: .utf8)
        let (name, spec) = ArchitectureYAMLImporter.parse(yaml)
        guard !spec.nodes.isEmpty else {
            throw ValidationError("No services found in \(input) — expected an 'architecture:'/'services:' Architecture-as-Code document.")
        }

        let (nodes, edges) = DiagramSpecMaterializer.materialize(spec)
        var page = DiagramPage(name: "Page 1", order: 0)
        for node in nodes {
            page.nodes[node.id] = node
            page.nodeZOrder.append(node.id)
        }
        for edge in edges {
            page.edges[edge.id] = edge
            page.edgeZOrder.append(edge.id)
        }

        var model = DiagramDocumentModel.blank(title: name ?? "Generated Architecture", at: Date())
        model.pages = [page.id: page]
        model.pageOrder = [page.id]

        let outputPath = output ?? defaultOutputPath(for: input)
        try PackageIO.write(model, to: outputPath)
        print("Wrote \(outputPath) (\(nodes.count) objects, \(edges.count) connectors)")
    }

    private func defaultOutputPath(for input: String) -> String {
        (input as NSString).deletingPathExtension + ".diagram"
    }
}
