import XCTest
import DiagramModel
@testable import DiagramInterop

final class DiagramDiffFormatterTests: XCTestCase {
    private func makeNode(label: String, type: ShapeType = .rectangle, criticality: String? = nil) -> DiagramNode {
        var metadata = Metadata()
        metadata.criticality = criticality
        return DiagramNode(type: type, position: Point2D(x: 0, y: 0), size: Size2D(width: 100, height: 60), text: TextContent(string: label), metadata: metadata)
    }

    private func makeModel(pageName: String, nodes: [DiagramNode]) -> DiagramDocumentModel {
        var page = DiagramPage(name: pageName, order: 0)
        for node in nodes { page.nodes[node.id] = node }
        page.nodeZOrder = nodes.map(\.id)
        var model = DiagramDocumentModel.blank(title: "Test", at: Date(timeIntervalSince1970: 0))
        model.pages = [page.id: page]
        model.pageOrder = [page.id]
        return model
    }

    func testMatchesTheSpecsExampleShape() {
        let old = makeModel(pageName: "Page 1", nodes: [
            makeNode(label: "Legacy API"),
            makeNode(label: "PostgreSQL", criticality: "Low")
        ])
        let new = makeModel(pageName: "Page 1", nodes: [
            makeNode(label: "Redis"),
            makeNode(label: "Kafka"),
            makeNode(label: "PostgreSQL", criticality: "High")
        ])

        let lines = DiagramDiffFormatter.diffLines(from: old, to: new)
        XCTAssertTrue(lines.contains("+ Redis"))
        XCTAssertTrue(lines.contains("+ Kafka"))
        XCTAssertTrue(lines.contains("- Legacy API"))
        XCTAssertTrue(lines.contains("~ PostgreSQL configuration changed"))
    }

    func testIdenticalModelsProduceNoLines() {
        let nodes = [makeNode(label: "A"), makeNode(label: "B")]
        let model = makeModel(pageName: "Page 1", nodes: nodes)
        XCTAssertTrue(DiagramDiffFormatter.diffLines(from: model, to: model).isEmpty)
    }

    func testAddedAndRemovedPagesAreReported() {
        var old = makeModel(pageName: "Page 1", nodes: [makeNode(label: "A")])
        let newPage = DiagramPage(name: "Page 2", order: 1)
        var new = old
        new.pages[newPage.id] = newPage
        new.pageOrder.append(newPage.id)

        let lines = DiagramDiffFormatter.diffLines(from: old, to: new)
        XCTAssertTrue(lines.contains("+ Page: Page 2"))

        // Reverse direction reports the removal instead.
        let reverseLines = DiagramDiffFormatter.diffLines(from: new, to: old)
        XCTAssertTrue(reverseLines.contains("- Page: Page 2"))
        _ = old // silence unused-mutation warning potential
    }

    func testNodeDiffLinesIsSymmetricWithPageDiff() {
        let oldByLabel = ["A": makeNode(label: "A"), "B": makeNode(label: "B")]
        let newByLabel = ["B": makeNode(label: "B"), "C": makeNode(label: "C")]
        let lines = DiagramDiffFormatter.nodeDiffLines(from: oldByLabel, to: newByLabel)
        XCTAssertEqual(Set(lines), ["+ C", "- A"])
    }
}
