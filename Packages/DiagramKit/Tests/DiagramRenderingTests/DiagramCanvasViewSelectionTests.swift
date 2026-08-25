import XCTest
import DiagramModel
@testable import DiagramRendering

/// Exercises the selection logic that doesn't require simulating real
/// mouse/`NSEvent` input (that's better covered by manual verification per
/// the plan's testing risk mitigation — keep real `NSView` instantiation to
/// a minimum). `applyExternalSelection` and `loadNodes`'s pruning are pure
/// enough to assert on directly.
final class DiagramCanvasViewSelectionTests: XCTestCase {
    private func makeNode() -> DiagramNode {
        DiagramNode(type: .rectangle, position: Point2D(x: 0, y: 0), size: Size2D(width: 100, height: 60))
    }

    func testApplyExternalSelectionUpdatesSelection() {
        let view = DiagramCanvasView()
        let node = makeNode()
        view.loadNodes([node])

        view.applyExternalSelection([node.id])
        XCTAssertEqual(view.selection, [node.id])

        view.applyExternalSelection([])
        XCTAssertEqual(view.selection, [])
    }

    func testApplyExternalSelectionDoesNotFireOnSelectionChange() {
        let view = DiagramCanvasView()
        let node = makeNode()
        view.loadNodes([node])

        var firedCount = 0
        view.onSelectionChange = { _ in firedCount += 1 }
        view.applyExternalSelection([node.id])

        XCTAssertEqual(firedCount, 0)
    }

    func testLoadNodesPrunesSelectionOfRemovedNodes() {
        let view = DiagramCanvasView()
        let nodeA = makeNode()
        let nodeB = makeNode()
        view.loadNodes([nodeA, nodeB])
        view.applyExternalSelection([nodeA.id, nodeB.id])

        view.loadNodes([nodeB])

        XCTAssertEqual(view.selection, [nodeB.id])
    }

    func testNodeCountReflectsLoadedNodes() {
        let view = DiagramCanvasView()
        XCTAssertEqual(view.nodeCount, 0)
        view.loadNodes([makeNode(), makeNode(), makeNode()])
        XCTAssertEqual(view.nodeCount, 3)
    }
}
