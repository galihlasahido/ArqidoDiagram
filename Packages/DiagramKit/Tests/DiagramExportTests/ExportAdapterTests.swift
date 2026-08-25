import XCTest
import DiagramModel
@testable import DiagramExport

final class ExportAdapterTests: XCTestCase {
    private func samplePage() -> DiagramPage {
        let a = DiagramNode(
            type: .rectangle,
            position: Point2D(x: 0, y: 0),
            size: Size2D(width: 120, height: 80),
            style: ShapeStyle(fill: ColorRef(red: 0.2, green: 0.4, blue: 0.9, alpha: 1)),
            text: TextContent(string: "Gateway")
        )
        let b = DiagramNode(type: .flowchartDatabase, position: Point2D(x: 300, y: 0), size: Size2D(width: 100, height: 90))
        let edge = DiagramEdge(source: .node(a.id, portID: nil), target: .node(b.id, portID: nil), style: LineStyle(endArrow: .filled))

        var page = DiagramPage(name: "Sample", order: 0)
        page.nodes = [a.id: a, b.id: b]
        page.edges = [edge.id: edge]
        page.nodeZOrder = [a.id, b.id]
        page.edgeZOrder = [edge.id]
        return page
    }

    private func tempURL(_ filename: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "-" + filename)
    }

    // MARK: - PNG

    func testPNGDataIsAValidPNGImage() async throws {
        let data = try await PNGExportAdapter.data(for: samplePage())
        // PNG magic bytes.
        XCTAssertEqual(Array(data.prefix(8)), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    }

    func testPNGWritesToDisk() async throws {
        let url = tempURL("export.png")
        defer { try? FileManager.default.removeItem(at: url) }
        try await PNGExportAdapter.write(samplePage(), to: url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let data = try Data(contentsOf: url)
        XCTAssertGreaterThan(data.count, 0)
    }

    func testPNGOfEmptyPageStillProducesAnImage() async throws {
        let empty = DiagramPage(name: "Empty", order: 0)
        let data = try await PNGExportAdapter.data(for: empty)
        XCTAssertGreaterThan(data.count, 0)
    }

    // MARK: - PDF

    func testPDFWritesAValidPDFFile() async throws {
        let url = tempURL("export.pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        try await PDFExportAdapter.write(samplePage(), to: url)

        let data = try Data(contentsOf: url)
        XCTAssertEqual(Array(data.prefix(5)), Array("%PDF-".utf8))
    }

    // MARK: - SVG

    func testSVGStringContainsExpectedElements() {
        let svg = SVGExportAdapter.string(for: samplePage())
        XCTAssertTrue(svg.hasPrefix("<svg"))
        XCTAssertTrue(svg.contains("</svg>"))
        XCTAssertTrue(svg.contains("<path"), "nodes and edges should render as SVG paths")
        XCTAssertTrue(svg.contains("Gateway"), "node text should appear as SVG text content")
    }

    func testSVGEscapesTextContent() {
        var page = DiagramPage(name: "Escaping", order: 0)
        let node = DiagramNode(
            type: .rectangle,
            position: Point2D(x: 0, y: 0),
            size: Size2D(width: 100, height: 60),
            text: TextContent(string: "A & B < C")
        )
        page.nodes = [node.id: node]
        let svg = SVGExportAdapter.string(for: page)
        XCTAssertTrue(svg.contains("A &amp; B &lt; C"))
        XCTAssertFalse(svg.contains("A & B < C"))
    }

    func testSVGWritesToDisk() async throws {
        let url = tempURL("export.svg")
        defer { try? FileManager.default.removeItem(at: url) }
        try await SVGExportAdapter.write(samplePage(), to: url)
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.hasPrefix("<svg"))
    }

    func testSVGOfEmptyPageIsStillValidXML() {
        let empty = DiagramPage(name: "Empty", order: 0)
        let svg = SVGExportAdapter.string(for: empty)
        XCTAssertTrue(svg.hasPrefix("<svg"))
        XCTAssertTrue(svg.hasSuffix("</svg>\n"))
    }
}
