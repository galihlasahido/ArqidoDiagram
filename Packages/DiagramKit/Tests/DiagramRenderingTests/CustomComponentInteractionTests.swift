import XCTest
import AppKit
import DiagramModel
@testable import DiagramRendering

final class CustomComponentInteractionTests: XCTestCase {
    private func makeView() -> DiagramCanvasView {
        let view = DiagramCanvasView(frame: NSRect(x: 0, y: 0, width: 1000, height: 800))
        view.viewport = CanvasViewport(scale: 1, contentOrigin: .zero)
        return view
    }

    func testCaptureNormalizesPositionsToSelectionBoundingBoxOrigin() throws {
        let view = makeView()
        let firstID = view.addNode(ofType: .rectangle, at: CGPoint(x: 100, y: 100))
        let secondID = view.addNode(ofType: .ellipse, at: CGPoint(x: 300, y: 200))
        view.applyExternalSelection([firstID, secondID])

        let component = try XCTUnwrap(view.captureSelectionAsComponent(name: "Pair", category: "Test"))
        let minX = try XCTUnwrap(component.nodes.map(\.position.x).min())
        let minY = try XCTUnwrap(component.nodes.map(\.position.y).min())
        XCTAssertEqual(minX, 0, accuracy: 0.01)
        XCTAssertEqual(minY, 0, accuracy: 0.01)
    }

    func testCaptureOnlyKeepsEdgesFullyInsideTheSelection() {
        let view = makeView()
        let insideA = view.addNode(ofType: .rectangle, at: CGPoint(x: 100, y: 100))
        let insideB = view.addNode(ofType: .rectangle, at: CGPoint(x: 300, y: 100))
        let outside = view.addNode(ofType: .rectangle, at: CGPoint(x: 500, y: 100))
        view.applyExternalSelection([insideA, insideB])

        let internalEdgeID = view.addEdge(from: .node(insideA, portID: nil), to: .node(insideB, portID: nil))
        let danglingEdgeID = view.addEdge(from: .node(insideA, portID: nil), to: .node(outside, portID: nil))

        let component = view.captureSelectionAsComponent(name: "Linked Pair", category: "Test")
        XCTAssertNotNil(component)
        XCTAssertEqual(component!.edges.map(\.id), [internalEdgeID])
        XCTAssertFalse(component!.edges.contains { $0.id == danglingEdgeID })
    }

    func testInsertClonesNodesAndEdgesWithFreshIDsAsOneUndoStep() {
        let view = makeView()
        let firstID = view.addNode(ofType: .rectangle, at: CGPoint(x: 0, y: 0))
        let secondID = view.addNode(ofType: .rectangle, at: CGPoint(x: 100, y: 0))
        view.applyExternalSelection([firstID, secondID])
        _ = view.addEdge(from: .node(firstID, portID: nil), to: .node(secondID, portID: nil))
        let component = view.captureSelectionAsComponent(name: "Two Boxes", category: "Test")!

        let countBefore = view.nodeCount
        view.insertComponent(component, at: CGPoint(x: 600, y: 600))
        XCTAssertEqual(view.nodeCount, countBefore + 2)
        // Selection after insert is exactly the two newly-created nodes —
        // none of them can be the originals (fresh IDs), and neither can
        // overlap `firstID`/`secondID`.
        XCTAssertEqual(view.selection.count, 2)
        XCTAssertTrue(view.selection.isDisjoint(with: [firstID, secondID]))
    }
}
