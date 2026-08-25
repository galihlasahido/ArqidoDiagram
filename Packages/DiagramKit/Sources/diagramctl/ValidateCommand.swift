import Foundation
import ArgumentParser
import DiagramModel
import DiagramValidation

/// `diagramctl validate architecture.diagram` (spec §34 + the exact
/// "Git -> CI/CD -> diagramctl validate -> Architecture Rules -> PASS/FAIL"
/// pipeline it draws) and §18's own "Architecture Score / 100" output
/// format. Exit code is 1 whenever an error-severity issue exists (or a
/// warning, with `--fail-on-warning`), which is what makes this usable as
/// a CI gate rather than just a report.
struct ValidateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "validate",
        abstract: "Run Architecture Validation rules against a .diagram package and print a PASS/FAIL score."
    )

    @Argument(help: "Path to the .diagram package.")
    var input: String

    @Option(name: .long, help: "Path to a JSON file of custom rules (an array of CustomRule objects).")
    var rules: String?

    @Flag(name: .customLong("fail-on-warning"), help: "Also exit non-zero when only warnings (no errors) are found.")
    var failOnWarning = false

    func run() throws {
        let model = try PackageIO.read(from: input)
        let customRules = try loadCustomRules()

        var allIssues: [ValidationIssue] = []
        for pageID in model.pageOrder {
            guard let page = model.pages[pageID] else { continue }
            allIssues += ValidationEngine.evaluate(page, customRules: customRules.map(CustomRuleEvaluator.init))
        }

        let score = architectureScore(for: allIssues)
        print("Architecture Score")
        print("\(score) / 100")
        print("")

        let firedRuleNames = Set(allIssues.map(\.ruleName))
        let allRuleNames = ValidationEngine.builtInRules.map(\.name) + customRules.map(\.name)
        for name in allRuleNames where !firedRuleNames.contains(name) {
            print("\u{2713} \(name)")
        }

        if !allIssues.isEmpty {
            print("")
            for issue in allIssues.sorted(by: { $0.severity == $1.severity ? $0.message < $1.message : $0.severity > $1.severity }) {
                let symbol = issue.severity == .error ? "\u{2717}" : "\u{26A0}"
                print("\(symbol) \(issue.message)")
            }
        }

        let hasErrors = allIssues.contains { $0.severity == .error }
        let hasWarnings = allIssues.contains { $0.severity == .warning }
        print("")
        print(hasErrors || (failOnWarning && hasWarnings) ? "FAIL" : "PASS")

        if hasErrors || (failOnWarning && hasWarnings) {
            throw ExitCode.failure
        }
    }

    private func loadCustomRules() throws -> [CustomRule] {
        guard let rulesPath = rules else { return [] }
        let data = try Data(contentsOf: URL(fileURLWithPath: rulesPath))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([CustomRule].self, from: data)
    }

    private func architectureScore(for issues: [ValidationIssue]) -> Int {
        var score = 100
        for issue in issues {
            switch issue.severity {
            case .error: score -= 15
            case .warning: score -= 5
            case .information: score -= 1
            }
        }
        return max(0, score)
    }
}
