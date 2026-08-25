import XCTest
@testable import DiagramModel

final class DocumentVersionTests: XCTestCase {
    func testIdenticalSnapshotsProduceAnEmptyDiff() {
        let model = DiagramDocumentModel.blank(at: Date(timeIntervalSince1970: 0))
        let diff = VersionComparator.diff(from: model, to: model)
        XCTAssertTrue(diff.isEmpty)
    }

    func testAddedNodeIsReflectedInDiff() {
        var old = DiagramDocumentModel.blank(at: Date(timeIntervalSince1970: 0))
        let pageID = old.pageOrder[0]
        var new = old

        let node = DiagramNode(type: .rectangle, position: Point2D(x: 0, y: 0), size: Size2D(width: 100, height: 60))
        var newPage = new.pages[pageID]!
        newPage.nodes[node.id] = node
        newPage.nodeZOrder = [node.id]
        new.pages[pageID] = newPage

        let diff = VersionComparator.diff(from: old, to: new)
        XCTAssertEqual(diff.nodesAdded, 1)
        XCTAssertEqual(diff.nodesRemoved, 0)
        XCTAssertEqual(diff.nodesModified, 0)
    }

    func testModifiedNodeIsCountedSeparatelyFromAddedOrRemoved() {
        let node = DiagramNode(type: .rectangle, position: Point2D(x: 0, y: 0), size: Size2D(width: 100, height: 60))
        var old = DiagramDocumentModel.blank(at: Date(timeIntervalSince1970: 0))
        let pageID = old.pageOrder[0]
        var oldPage = old.pages[pageID]!
        oldPage.nodes[node.id] = node
        oldPage.nodeZOrder = [node.id]
        old.pages[pageID] = oldPage

        var new = old
        var movedNode = node
        movedNode.position = Point2D(x: 500, y: 500)
        var newPage = new.pages[pageID]!
        newPage.nodes[node.id] = movedNode
        new.pages[pageID] = newPage

        let diff = VersionComparator.diff(from: old, to: new)
        XCTAssertEqual(diff.nodesModified, 1)
        XCTAssertEqual(diff.nodesAdded, 0)
        XCTAssertEqual(diff.nodesRemoved, 0)
    }

    func testAddedPageIsReflectedInDiff() {
        let old = DiagramDocumentModel.blank(at: Date(timeIntervalSince1970: 0))
        var new = old
        let extraPage = DiagramPage(name: "Extra", order: 1)
        new.pages[extraPage.id] = extraPage
        new.pageOrder.append(extraPage.id)

        let diff = VersionComparator.diff(from: old, to: new)
        XCTAssertEqual(diff.pagesAdded, 1)
        XCTAssertEqual(diff.pagesRemoved, 0)
    }
}
