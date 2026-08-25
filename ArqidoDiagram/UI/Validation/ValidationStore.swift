import Foundation
import DiagramModel
import DiagramValidation
import DiagramPersistence

/// Thin `ObservableObject` wrapper around `DiagramPersistence.
/// CustomRuleLibrary`, the same layering `CustomComponentStore` uses for
/// `CustomComponentLibrary`. Also the one place that turns the page-level
/// `ValidationEngine.evaluate` call into something the Validation panel can
/// observe, folding in whatever custom rules are currently saved.
final class ValidationStore: ObservableObject {
    @Published private(set) var customRules: [CustomRule]
    private let library = CustomRuleLibrary()

    init() {
        customRules = library.rules
    }

    func save(_ rule: CustomRule) {
        customRules = library.save(rule)
    }

    func delete(id: UUID) {
        customRules = library.delete(id: id)
    }

    func issues(for page: DiagramPage) -> [ValidationIssue] {
        ValidationEngine.evaluate(page, customRules: customRules.map(CustomRuleEvaluator.init))
    }
}
