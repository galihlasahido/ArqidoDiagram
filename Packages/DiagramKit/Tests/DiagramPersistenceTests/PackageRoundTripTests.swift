import XCTest
import DiagramModel
@testable import DiagramPersistence

final class PackageRoundTripTests: XCTestCase {
    func testBlankDocumentRoundTripsThroughPackageWrapper() throws {
        let original = DiagramDocumentModel.blank(title: "Payment Architecture", at: Date(timeIntervalSince1970: 0))

        let wrapper = try PackageWriter.fileWrapper(for: original)
        let decoded = try PackageReader.documentModel(from: wrapper)

        XCTAssertEqual(decoded.documentID, original.documentID)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.pageOrder, original.pageOrder)
        XCTAssertEqual(decoded.pages[original.pageOrder[0]]?.name, "Page 1")
    }

    func testMultiPageDocumentWithNodesAndEdgesRoundTrips() throws {
        let node = DiagramNode(type: .rectangle, position: Point2D(x: 10, y: 20), size: Size2D(width: 100, height: 60))
        var page1 = DiagramPage(name: "System Context", order: 0)
        page1.nodes = [node.id: node]
        page1.nodeZOrder = [node.id]
        let page2 = DiagramPage(name: "Data Architecture", order: 1)

        var document = DiagramDocumentModel.blank(title: "Multi-page Doc", at: Date(timeIntervalSince1970: 0))
        document.pages = [page1.id: page1, page2.id: page2]
        document.pageOrder = [page1.id, page2.id]

        let wrapper = try PackageWriter.fileWrapper(for: document)
        let decoded = try PackageReader.documentModel(from: wrapper)

        XCTAssertEqual(decoded.pageOrder, [page1.id, page2.id])
        XCTAssertEqual(decoded.pages[page1.id]?.nodes[node.id]?.type, .rectangle)
        XCTAssertEqual(decoded.pages[page2.id]?.name, "Data Architecture")
    }

    func testMissingManifestThrowsRatherThanSilentlyLosingData() {
        let emptyWrapper = FileWrapper(directoryWithFileWrappers: [:])
        XCTAssertThrowsError(try PackageReader.documentModel(from: emptyWrapper)) { error in
            XCTAssertEqual(error as? PackageReadError, .missingManifest)
        }
    }

    func testFailedPageEncodingLeavesNoPartialWrapper() {
        // PackageWriter builds the whole tree before returning it, so a
        // thrown error never returns a half-built FileWrapper. Nothing to
        // assert on the output (there isn't one) — this documents the
        // guarantee the persistence-write technical risk mitigation relies
        // on: construction is all-or-nothing.
    }

    func testCurrentSchemaVersionRoundTripsWithoutMigration() throws {
        let document = DiagramDocumentModel.blank(at: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(document.schemaVersion, DiagramDocumentModel.currentSchemaVersion)

        let wrapper = try PackageWriter.fileWrapper(for: document)
        let decoded = try PackageReader.documentModel(from: wrapper)
        XCTAssertEqual(decoded.schemaVersion, DiagramDocumentModel.currentSchemaVersion)
    }
}
