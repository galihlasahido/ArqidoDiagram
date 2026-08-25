import Foundation
import ArgumentParser
import DiagramModel
import DiagramInterop

/// `diagramctl compare-env architecture.diagram --from Production --to
/// Staging` (spec §19 "Environment Modeling": "Compare environments,
/// Highlight differences", worked example "Production vs Staging / +
/// Redis / - Legacy API / ~ PostgreSQL configuration changed"). Compares
/// two `Metadata.environment` tags *within one document* — the app-level
/// counterpart, "Duplicate Environment", is a canvas action (clone the
/// selection with a different environment tag), not a CLI concern.
///
/// Diff direction matches `diff`'s convention: `+` exists in `--to` but
/// not `--from`, `-` exists in `--from` but not `--to`.
struct CompareEnvironmentsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "compare-env",
        abstract: "Compare two environment tags (e.g. Production vs Staging) within one .diagram package."
    )

    @Argument(help: "Path to the .diagram package.")
    var input: String

    @Option(name: .long, help: "The environment tag to compare from, e.g. Staging.")
    var from: String

    @Option(name: .long, help: "The environment tag to compare to, e.g. Production.")
    var to: String

    func run() throws {
        let model = try PackageIO.read(from: input)
        let allNodes = model.pageOrder.compactMap { model.pages[$0] }.flatMap { $0.nodes.values }

        func label(_ node: DiagramNode) -> String {
            node.text?.string.isEmpty == false ? node.text!.string : node.type.rawValue
        }

        let fromNodes = allNodes.filter { $0.metadata.environment == from }
        let toNodes = allNodes.filter { $0.metadata.environment == to }
        guard !fromNodes.isEmpty || !toNodes.isEmpty else {
            print("No objects tagged \"\(from)\" or \"\(to)\" were found.")
            return
        }

        let fromByLabel = Dictionary(fromNodes.map { (label($0), $0) }, uniquingKeysWith: { first, _ in first })
        let toByLabel = Dictionary(toNodes.map { (label($0), $0) }, uniquingKeysWith: { first, _ in first })

        print("\(from) vs \(to)")
        print("")

        let lines = DiagramDiffFormatter.nodeDiffLines(from: fromByLabel, to: toByLabel)
        if lines.isEmpty {
            print("No differences.")
        } else {
            for line in lines { print(line) }
        }
    }
}
