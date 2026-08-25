import XCTest
import DiagramModel
import DiagramLayout
@testable import DiagramInterop

final class ExporterTests: XCTestCase {
    private func makeNode(type: ShapeType, label: String, semanticType: String? = nil) -> DiagramNode {
        DiagramNode(
            type: type,
            position: Point2D(x: 0, y: 0),
            size: Size2D(width: 120, height: 80),
            text: TextContent(string: label),
            metadata: Metadata(semanticType: semanticType)
        )
    }

    private func makePage(nodes: [DiagramNode], edges: [DiagramEdge] = []) -> DiagramPage {
        var page = DiagramPage(name: "Test", order: 0)
        for node in nodes { page.nodes[node.id] = node }
        page.nodeZOrder = nodes.map(\.id)
        for edge in edges { page.edges[edge.id] = edge }
        page.edgeZOrder = edges.map(\.id)
        return page
    }

    // MARK: - Architecture YAML round trip (spec §24's own example shape)

    func testArchitectureYAMLRoundTrip() {
        let gateway = makeNode(type: .networkGateway, label: "API Gateway", semanticType: "gateway")
        let service = makeNode(type: .c4Container, label: "Payment Service", semanticType: "service")
        let db = makeNode(type: .flowchartDatabase, label: "PostgreSQL", semanticType: "database")
        let edges = [
            DiagramEdge(source: .node(gateway.id, portID: nil), target: .node(service.id, portID: nil)),
            DiagramEdge(source: .node(service.id, portID: nil), target: .node(db.id, portID: nil))
        ]
        let page = makePage(nodes: [gateway, service, db], edges: edges)

        let yaml = ArchitectureYAMLExporter.export(page, architectureName: "Payment Platform")
        XCTAssertTrue(yaml.contains("name: Payment Platform"))
        XCTAssertTrue(yaml.contains("name: API Gateway"))
        XCTAssertTrue(yaml.contains("type: gateway"))

        let (name, spec) = ArchitectureYAMLImporter.parse(yaml)
        XCTAssertEqual(name, "Payment Platform")
        XCTAssertEqual(spec.nodes.count, 3)
        XCTAssertEqual(spec.edges.count, 2)
        XCTAssertTrue(spec.nodes.contains { $0.label == "Payment Service" && $0.type == "service" })
    }

    func testArchitectureYAMLImportMatchesSpecExample() {
        let yaml = """
        architecture:
          name: Payment Platform

        services:
          - name: API Gateway
            type: gateway

          - name: Payment Service
            type: service

          - name: PostgreSQL
            type: database

        connections:
          - from: API Gateway
            to: Payment Service

          - from: Payment Service
            to: PostgreSQL
        """
        let (name, spec) = ArchitectureYAMLImporter.parse(yaml)
        XCTAssertEqual(name, "Payment Platform")
        XCTAssertEqual(spec.nodes.count, 3)
        XCTAssertEqual(spec.edges.count, 2)
        XCTAssertEqual(spec.edges.first?.from, "API Gateway")
        XCTAssertEqual(spec.edges.first?.to, "Payment Service")
    }

    // MARK: - Mermaid

    func testMermaidExportUsesShapeHintsAndArrows() {
        let person = makeNode(type: .c4Person, label: "Customer")
        let db = makeNode(type: .flowchartDatabase, label: "PostgreSQL")
        let edge = DiagramEdge(source: .node(person.id, portID: nil), target: .node(db.id, portID: nil))
        let page = makePage(nodes: [person, db], edges: [edge])

        let mermaid = MermaidExporter.export(page)
        XCTAssertTrue(mermaid.hasPrefix("graph TD"))
        XCTAssertTrue(mermaid.contains("((Customer))"))
        XCTAssertTrue(mermaid.contains("[(PostgreSQL)]"))
        XCTAssertTrue(mermaid.contains("-->"))
    }

    // MARK: - PlantUML

    func testPlantUMLExportWrapsInStartEndTags() {
        let node = makeNode(type: .c4Container, label: "Service")
        let page = makePage(nodes: [node])
        let output = PlantUMLExporter.export(page)
        XCTAssertTrue(output.hasPrefix("@startuml"))
        XCTAssertTrue(output.hasSuffix("@enduml\n"))
        XCTAssertTrue(output.contains("\"Service\""))
    }

    // MARK: - Graphviz

    func testGraphvizExportProducesValidDigraphStructure() {
        let a = makeNode(type: .rectangle, label: "A")
        let b = makeNode(type: .flowchartDatabase, label: "B")
        let edge = DiagramEdge(source: .node(a.id, portID: nil), target: .node(b.id, portID: nil))
        let page = makePage(nodes: [a, b], edges: [edge])

        let dot = GraphvizExporter.export(page, name: "My Diagram")
        XCTAssertTrue(dot.hasPrefix("digraph My_Diagram {"))
        XCTAssertTrue(dot.contains("shape=cylinder"))
        XCTAssertTrue(dot.contains("->"))
        XCTAssertTrue(dot.hasSuffix("}\n"))
    }

    // MARK: - SQL export (inverse of SQLSchemaImporter)

    func testSQLExportRoundTripsThroughSQLSchemaImporter() {
        let sql = """
        CREATE TABLE customers (
            id INT PRIMARY KEY,
            name VARCHAR(255)
        );

        CREATE TABLE orders (
            id INT PRIMARY KEY,
            customer_id INT REFERENCES customers(id)
        );
        """
        let importedSpec = SQLSchemaImporter.parse(sql)
        let (nodes, edges) = DiagramSpecMaterializer.materialize(importedSpec)
        let page = makePage(nodes: nodes, edges: edges)

        let exportedSQL = SQLExporter.export(page)
        XCTAssertTrue(exportedSQL.contains("CREATE TABLE customers"))
        XCTAssertTrue(exportedSQL.contains("CREATE TABLE orders"))
        XCTAssertTrue(exportedSQL.contains("id INTEGER PRIMARY KEY"))
        XCTAssertTrue(exportedSQL.contains("REFERENCES customers"))

        // Re-importing the exported SQL should still yield the same two entities.
        let reimported = SQLSchemaImporter.parse(exportedSQL)
        XCTAssertEqual(Set(reimported.nodes.filter { $0.type == "entity" }.map(\.label)), ["customers", "orders"])
    }

    func testSQLExportOnPageWithNoEntitiesIsEmpty() {
        let page = makePage(nodes: [makeNode(type: .rectangle, label: "Not an ERD entity")])
        XCTAssertEqual(SQLExporter.export(page), "")
    }
}
