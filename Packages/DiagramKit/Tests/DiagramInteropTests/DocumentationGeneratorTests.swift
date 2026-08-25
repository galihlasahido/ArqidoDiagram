import XCTest
import DiagramModel
@testable import DiagramInterop

final class DocumentationGeneratorTests: XCTestCase {
    func testMatchesTheSpecsExampleFormat() {
        var metadata = Metadata()
        metadata.technology = "Spring Boot"
        metadata.owner = "Payment Team"
        metadata.environment = "Production"
        metadata.criticality = "High"
        metadata.notes = "Handles payment transactions."
        let node = DiagramNode(
            type: .c4Container,
            position: Point2D(x: 0, y: 0),
            size: Size2D(width: 120, height: 80),
            text: TextContent(string: "Payment Service"),
            metadata: metadata
        )
        var page = DiagramPage(name: "Page 1", order: 0)
        page.nodes[node.id] = node
        page.nodeZOrder = [node.id]

        let markdown = DocumentationGenerator.markdown(title: "Payment Platform", pages: [page])

        XCTAssertTrue(markdown.contains("# Payment Platform"))
        XCTAssertTrue(markdown.contains("## Payment Service"))
        XCTAssertTrue(markdown.contains("**Technology:** Spring Boot"))
        XCTAssertTrue(markdown.contains("**Owner:** Payment Team"))
        XCTAssertTrue(markdown.contains("**Environment:** Production"))
        XCTAssertTrue(markdown.contains("**Criticality:** High"))
        XCTAssertTrue(markdown.contains("**Description:** Handles payment transactions."))
    }

    func testSkipsEmptyFieldsRatherThanPrintingBlankLabels() {
        let node = DiagramNode(type: .rectangle, position: Point2D(x: 0, y: 0), size: Size2D(width: 100, height: 60), text: TextContent(string: "Bare Node"))
        var page = DiagramPage(name: "Page 1", order: 0)
        page.nodes[node.id] = node
        page.nodeZOrder = [node.id]

        let markdown = DocumentationGenerator.markdown(title: "Doc", pages: [page])
        XCTAssertFalse(markdown.contains("**Technology:**"))
        XCTAssertFalse(markdown.contains("**Owner:**"))
    }

    func testMultiplePagesGetTheirOwnHeadingAndDeeperNodeHeadings() {
        let nodeA = DiagramNode(type: .rectangle, position: Point2D(x: 0, y: 0), size: Size2D(width: 100, height: 60), text: TextContent(string: "A"))
        var pageA = DiagramPage(name: "System Context", order: 0)
        pageA.nodes[nodeA.id] = nodeA
        pageA.nodeZOrder = [nodeA.id]

        let nodeB = DiagramNode(type: .rectangle, position: Point2D(x: 0, y: 0), size: Size2D(width: 100, height: 60), text: TextContent(string: "B"))
        var pageB = DiagramPage(name: "Data Architecture", order: 1)
        pageB.nodes[nodeB.id] = nodeB
        pageB.nodeZOrder = [nodeB.id]

        let markdown = DocumentationGenerator.markdown(title: "Doc", pages: [pageA, pageB])
        XCTAssertTrue(markdown.contains("## System Context"))
        XCTAssertTrue(markdown.contains("### A"))
        XCTAssertTrue(markdown.contains("## Data Architecture"))
        XCTAssertTrue(markdown.contains("### B"))
    }

    func testHTMLEscapesContentAndIncludesSameFields() {
        var metadata = Metadata()
        metadata.technology = "React & TypeScript"
        metadata.notes = "Renders <checkout> flow"
        let node = DiagramNode(
            type: .rectangle,
            position: Point2D(x: 0, y: 0),
            size: Size2D(width: 100, height: 60),
            text: TextContent(string: "Web App"),
            metadata: metadata
        )
        var page = DiagramPage(name: "Page 1", order: 0)
        page.nodes[node.id] = node
        page.nodeZOrder = [node.id]

        let html = DocumentationGenerator.html(title: "Doc", pages: [page])
        XCTAssertTrue(html.contains("<h1>Doc</h1>"))
        XCTAssertTrue(html.contains("<h2>Web App</h2>"))
        XCTAssertTrue(html.contains("React &amp; TypeScript"))
        XCTAssertTrue(html.contains("&lt;checkout&gt;"))
        XCTAssertFalse(html.contains("<checkout>"))
    }

    func testEmptyPageIsOmittedEntirely() {
        let page = DiagramPage(name: "Empty Page", order: 0)
        let markdown = DocumentationGenerator.markdown(title: "Doc", pages: [page])
        XCTAssertFalse(markdown.contains("Empty Page"))
    }
}
