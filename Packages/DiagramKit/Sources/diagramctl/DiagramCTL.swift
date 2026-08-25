import ArgumentParser

/// Spec §34 "CLI" — "Optional enterprise feature", designed for the exact
/// pipeline the spec draws: `Git -> CI/CD -> diagramctl validate ->
/// Architecture Rules -> PASS/FAIL`. Conforms to `AsyncParsableCommand`
/// (not plain `ParsableCommand`) because `export` needs async — the
/// PNG/PDF/SVG adapters it calls already are — and ArgumentParser requires
/// the root of a command tree to be async-aware if any subcommand is.
@main
struct DiagramCTL: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "diagramctl",
        abstract: "Command-line tools for ArqidoDiagram .diagram packages.",
        subcommands: [
            GenerateCommand.self,
            ValidateCommand.self,
            ExportCommand.self,
            DiffCommand.self,
            CompareEnvironmentsCommand.self,
            DocumentCommand.self
        ]
    )
}
