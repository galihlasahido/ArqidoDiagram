import XCTest
import DiagramValidation
@testable import DiagramPersistence

final class CustomRuleLibraryTests: XCTestCase {
    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeRule(name: String) -> CustomRule {
        CustomRule(name: name, subjectType: "database", relatedType: "firewall", requireRelated: true, severity: .warning, message: "")
    }

    func testSavedRulePersistsAcrossLibraryInstances() throws {
        let dir = try makeTempDirectory()
        let library = CustomRuleLibrary(directory: dir)
        library.save(makeRule(name: "Databases need a firewall"))

        let reloaded = CustomRuleLibrary(directory: dir)
        XCTAssertEqual(reloaded.rules.count, 1)
        XCTAssertEqual(reloaded.rules.first?.name, "Databases need a firewall")
    }

    func testDeleteRemovesRuleFromDiskToo() throws {
        let dir = try makeTempDirectory()
        let library = CustomRuleLibrary(directory: dir)
        let rule = makeRule(name: "Temp Rule")
        library.save(rule)
        library.delete(id: rule.id)

        let reloaded = CustomRuleLibrary(directory: dir)
        XCTAssertTrue(reloaded.rules.isEmpty)
    }
}
