import XCTest
@testable import DiagramModel

final class ArchitectureDecisionRecordTests: XCTestCase {
    func testMarkdownMatchesTheSpecsExampleFormat() {
        let adr = ArchitectureDecisionRecord(
            number: 1,
            title: "Use Kafka for asynchronous integration",
            status: .accepted,
            context: "Payment service requires asynchronous processing.",
            decision: "Use Apache Kafka.",
            consequences: ["+ High throughput", "+ Decoupling", "- Operational complexity"]
        )
        let markdown = adr.markdown

        XCTAssertTrue(markdown.contains("ADR-001"))
        XCTAssertTrue(markdown.contains("Title:\nUse Kafka for asynchronous integration"))
        XCTAssertTrue(markdown.contains("Status:\nAccepted"))
        XCTAssertTrue(markdown.contains("Context:\nPayment service requires asynchronous processing."))
        XCTAssertTrue(markdown.contains("Decision:\nUse Apache Kafka."))
        XCTAssertTrue(markdown.contains("+ High throughput"))
    }

    func testNumberIsZeroPadded() {
        let adr = ArchitectureDecisionRecord(number: 42, title: "Test")
        XCTAssertTrue(adr.markdown.contains("ADR-042"))
    }

    func testEmptyOptionalSectionsAreOmitted() {
        let adr = ArchitectureDecisionRecord(number: 1, title: "Bare Record")
        let markdown = adr.markdown
        XCTAssertFalse(markdown.contains("Context:"))
        XCTAssertFalse(markdown.contains("Decision:"))
        XCTAssertFalse(markdown.contains("Consequences:"))
    }
}
