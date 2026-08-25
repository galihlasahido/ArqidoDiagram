import XCTest
@testable import DiagramModel

final class DiagramDocumentModelCodableTests: XCTestCase {
    func testBlankDocumentRoundTripsThroughJSON() throws {
        let now = Date(timeIntervalSince1970: 0)
        let original = DiagramDocumentModel.blank(title: "Payment Architecture", at: now)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DiagramDocumentModel.self, from: data)

        XCTAssertEqual(decoded.documentID, original.documentID)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.pageOrder, original.pageOrder)
        XCTAssertEqual(decoded.pages.count, 1)
        XCTAssertEqual(decoded.pages[original.pageOrder[0]]?.name, "Page 1")
    }

    func testPopulatedPageRoundTripsThroughJSON() throws {
        let nodeA = DiagramNode(
            type: .rectangle,
            position: Point2D(x: 100, y: 100),
            size: Size2D(width: 200, height: 80),
            metadata: Metadata(fields: ["technology": "Spring Boot", "criticality": "high"], tags: ["payments"])
        )
        let nodeB = DiagramNode(
            type: .flowchartDatabase,
            position: Point2D(x: 400, y: 100),
            size: Size2D(width: 160, height: 100)
        )
        let edge = DiagramEdge(
            source: .node(nodeA.id, portID: nil),
            target: .node(nodeB.id, portID: nil),
            routing: .orthogonal,
            style: LineStyle(endArrow: .filled)
        )
        var page = DiagramPage(name: "System Context", order: 0)
        page.nodes = [nodeA.id: nodeA, nodeB.id: nodeB]
        page.edges = [edge.id: edge]
        page.nodeZOrder = [nodeA.id, nodeB.id]
        page.edgeZOrder = [edge.id]

        var document = DiagramDocumentModel.blank(title: "Payment Architecture", at: Date(timeIntervalSince1970: 0))
        document.pages = [page.id: page]
        document.pageOrder = [page.id]

        let data = try JSONEncoder().encode(document)
        let decoded = try JSONDecoder().decode(DiagramDocumentModel.self, from: data)

        let decodedPage = try XCTUnwrap(decoded.pages[page.id])
        XCTAssertEqual(decodedPage.nodes.count, 2)
        XCTAssertEqual(decodedPage.nodes[nodeA.id]?.metadata.technology, "Spring Boot")
        XCTAssertEqual(decodedPage.edges[edge.id]?.routing, .orthogonal)
        XCTAssertEqual(decodedPage.edges[edge.id]?.source, .node(nodeA.id, portID: nil))
        XCTAssertEqual(decodedPage.nodeZOrder, [nodeA.id, nodeB.id])
    }

    func testSchemaVersionDefaultsToCurrent() {
        let document = DiagramDocumentModel.blank(at: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(document.schemaVersion, DiagramDocumentModel.currentSchemaVersion)
    }
}
