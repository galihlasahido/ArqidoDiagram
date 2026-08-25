import Foundation
import ArgumentParser
import DiagramInterop

/// `diagramctl diff old.diagram new.diagram` (spec §30/§34 "Diagram diff").
/// See `DiagramInterop.DiagramDiffFormatter` for the actual comparison —
/// this is just the CLI's file-in/lines-out wrapper around it.
struct DiffCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "diff",
        abstract: "Compare two .diagram packages and report added/removed/changed objects."
    )

    @Argument(help: "Path to the earlier .diagram package.")
    var old: String

    @Argument(help: "Path to the later .diagram package.")
    var new: String

    func run() throws {
        let oldModel = try PackageIO.read(from: old)
        let newModel = try PackageIO.read(from: new)
        let lines = DiagramDiffFormatter.diffLines(from: oldModel, to: newModel)

        if lines.isEmpty {
            print("No differences.")
            return
        }
        for line in lines { print(line) }
    }
}
