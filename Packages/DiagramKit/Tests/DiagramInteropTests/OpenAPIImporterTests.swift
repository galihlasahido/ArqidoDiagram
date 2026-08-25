import XCTest
@testable import DiagramInterop

final class OpenAPIImporterTests: XCTestCase {
    func testGroupsPathsByTagAndIncludesSchemas() {
        let document = """
        openapi: 3.0.0
        info:
          title: Payment API
        paths:
          /payments:
            post:
              tags:
                - Payments
          /payments/{id}:
            get:
              tags:
                - Payments
          /health:
            get:
              tags:
                - System
        components:
          schemas:
            Payment:
              type: object
        """
        let spec = OpenAPIImporter.parse(document)

        XCTAssertTrue(spec.nodes.contains { $0.label == "Payment API" && $0.type == "gateway" })
        XCTAssertTrue(spec.nodes.contains { $0.label == "Payments" })
        XCTAssertTrue(spec.nodes.contains { $0.label == "System" })
        XCTAssertTrue(spec.nodes.contains { $0.label == "Payment" && $0.type == "entity" })

        // Two paths share the "Payments" tag, so exactly one tag node + one edge, not two.
        let paymentsEdges = spec.edges.filter { edge in
            spec.nodes.first { $0.id == edge.to }?.label == "Payments"
        }
        XCTAssertEqual(paymentsEdges.count, 1)
    }

    func testFallsBackToPathWhenUntagged() {
        let document = """
        info:
          title: Untagged API
        paths:
          /widgets:
            get:
              summary: List widgets
        """
        let spec = OpenAPIImporter.parse(document)
        XCTAssertTrue(spec.nodes.contains { $0.label == "/widgets" })
    }
}
