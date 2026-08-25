import XCTest
@testable import DiagramInterop

final class SQLSchemaImporterTests: XCTestCase {
    func testInlinePrimaryKeyAndForeignKey() {
        let sql = """
        CREATE TABLE customers (
            id INT PRIMARY KEY,
            name VARCHAR(255)
        );

        CREATE TABLE orders (
            id INT PRIMARY KEY,
            customer_id INT REFERENCES customers(id),
            total DECIMAL(10,2)
        );
        """
        let spec = SQLSchemaImporter.parse(sql)

        XCTAssertEqual(spec.nodes.filter { $0.type == "entity" }.map(\.label).sorted(), ["customers", "orders"])
        XCTAssertTrue(spec.nodes.contains { $0.label == "id" && $0.type == "primary key" })
        XCTAssertTrue(spec.nodes.contains { $0.label == "customer_id" && $0.type == "foreign key" })
        XCTAssertTrue(spec.nodes.contains { $0.label == "name" && $0.type == "attribute" })

        // Entity -> attribute edges, plus one FK-column -> referenced-entity edge.
        let referenceEdge = spec.edges.first { $0.label == "references" }
        XCTAssertNotNil(referenceEdge)
        let fkNode = spec.nodes.first { $0.id == referenceEdge?.from }
        XCTAssertEqual(fkNode?.label, "customer_id")
        let targetEntity = spec.nodes.first { $0.id == referenceEdge?.to }
        XCTAssertEqual(targetEntity?.label, "customers")
    }

    func testTableLevelForeignKeyConstraint() {
        let sql = """
        CREATE TABLE orders (id INT PRIMARY KEY);
        CREATE TABLE products (id INT PRIMARY KEY);
        CREATE TABLE line_items (
            order_id INT,
            product_id INT,
            FOREIGN KEY (order_id) REFERENCES orders(id),
            FOREIGN KEY (product_id) REFERENCES products(id)
        );
        """
        let spec = SQLSchemaImporter.parse(sql)
        let referenceEdges = spec.edges.filter { $0.label == "references" }
        XCTAssertEqual(referenceEdges.count, 2)

        let targets = referenceEdges.compactMap { edge in spec.nodes.first { $0.id == edge.to }?.label }
        XCTAssertEqual(Set(targets), ["orders", "products"])
    }

    func testTableLevelCompositePrimaryKey() {
        let sql = """
        CREATE TABLE enrollments (
            student_id INT,
            course_id INT,
            PRIMARY KEY (student_id, course_id)
        );
        """
        let spec = SQLSchemaImporter.parse(sql)
        let primaryKeyLabels = Set(spec.nodes.filter { $0.type == "primary key" }.map(\.label))
        XCTAssertEqual(primaryKeyLabels, ["student_id", "course_id"])
    }

    func testIgnoresSQLCommentsAndIsCaseInsensitive() {
        let sql = """
        -- customer table
        create table Users (
            Id int primary key, -- the id
            Email varchar(255)
        );
        """
        let spec = SQLSchemaImporter.parse(sql)
        XCTAssertEqual(spec.nodes.first { $0.type == "entity" }?.label, "Users")
        XCTAssertTrue(spec.nodes.contains { $0.label == "Id" && $0.type == "primary key" })
    }

    func testEveryNonEntityNodeHasAnEdgeFromItsEntity() {
        let sql = "CREATE TABLE products (id INT PRIMARY KEY, name VARCHAR(100), price DECIMAL(10,2));"
        let spec = SQLSchemaImporter.parse(sql)
        let entityID = spec.nodes.first { $0.type == "entity" }!.id
        let attributeIDs = spec.nodes.filter { $0.type != "entity" }.map(\.id)
        for attributeID in attributeIDs {
            XCTAssertTrue(spec.edges.contains { $0.from == entityID && $0.to == attributeID })
        }
    }
}
