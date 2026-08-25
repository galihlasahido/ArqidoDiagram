import XCTest
import AppKit
import DiagramModel
@testable import DiagramRendering

/// Same synthetic-`NSEvent`-against-an-offscreen-window technique as
/// `DiagramCanvasViewInteractionTests`'s `Harness` (kept as a private
/// duplicate rather than shared, matching that file's own `private` scope).
private final class Harness {
    let window: NSWindow
    let view: DiagramCanvasView

    init(frame: NSRect = NSRect(x: 0, y: 0, width: 1000, height: 800)) {
        window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: true)
        view = DiagramCanvasView(frame: frame)
        window.contentView = view
        view.viewport = CanvasViewport(scale: 1, contentOrigin: .zero)
    }

    private func event(_ type: NSEvent.EventType, at viewPoint: CGPoint, modifiers: NSEvent.ModifierFlags) -> NSEvent {
        let windowPoint = view.convert(viewPoint, to: nil)
        return NSEvent.mouseEvent(
            with: type,
            location: windowPoint,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )!
    }

    func click(at point: CGPoint, modifiers: NSEvent.ModifierFlags = []) {
        view.mouseDown(with: event(.leftMouseDown, at: point, modifiers: modifiers))
        view.mouseUp(with: event(.leftMouseUp, at: point, modifiers: modifiers))
    }

    func drag(from start: CGPoint, to end: CGPoint, modifiers: NSEvent.ModifierFlags = []) {
        view.mouseDown(with: event(.leftMouseDown, at: start, modifiers: modifiers))
        view.mouseDragged(with: event(.leftMouseDragged, at: end, modifiers: modifiers))
        view.mouseUp(with: event(.leftMouseUp, at: end, modifiers: modifiers))
    }
}

final class EdgeSelectionInteractionTests: XCTestCase {
    private func page(nodes: [DiagramNode], edges: [DiagramEdge]) -> DiagramPage {
        var page = DiagramPage(name: "Test", order: 0)
        for node in nodes {
            page.nodes[node.id] = node
            page.nodeZOrder.append(node.id)
        }
        for edge in edges {
            page.edges[edge.id] = edge
            page.edgeZOrder.append(edge.id)
        }
        return page
    }

    /// Two nodes 300pt apart with a `.point`-to-`.point` straight edge
    /// running between them, clear of either node's bounding box — so a
    /// click at its midpoint can only hit the edge, never a node.
    private func makeStraightEdgeFixture() -> (Harness, DiagramEdge) {
        let edge = DiagramEdge(source: .point(Point2D(x: 0, y: 0)), target: .point(Point2D(x: 300, y: 0)), routing: .straight)
        let h = Harness()
        h.view.loadPage(page(nodes: [], edges: [edge]))
        return (h, edge)
    }

    func testClickingOnAnEdgeSelectsIt() {
        let (h, edge) = makeStraightEdgeFixture()
        h.click(at: CGPoint(x: 150, y: 0))
        XCTAssertEqual(h.view.edgeSelection, [edge.id])
    }

    func testClickingEmptySpaceClearsEdgeSelection() {
        let (h, edge) = makeStraightEdgeFixture()
        h.click(at: CGPoint(x: 150, y: 0))
        XCTAssertEqual(h.view.edgeSelection, [edge.id])

        h.click(at: CGPoint(x: 700, y: 700))
        XCTAssertEqual(h.view.edgeSelection, [])
    }

    func testSelectingAnEdgeClearsNodeSelectionAndViceVersa() {
        let node = DiagramNode(type: .rectangle, position: Point2D(x: 500, y: 500), size: Size2D(width: 100, height: 60))
        let edge = DiagramEdge(source: .point(Point2D(x: 0, y: 0)), target: .point(Point2D(x: 300, y: 0)), routing: .straight)
        let h = Harness()
        h.view.loadPage(page(nodes: [node], edges: [edge]))

        h.click(at: CGPoint(x: 550, y: 530))
        XCTAssertEqual(h.view.selection, [node.id])
        XCTAssertEqual(h.view.edgeSelection, [])

        h.click(at: CGPoint(x: 150, y: 0))
        XCTAssertEqual(h.view.edgeSelection, [edge.id])
        XCTAssertEqual(h.view.selection, [], "selecting the edge should have cleared the node selection")
    }

    func testEdgeHitTestFollowsNonStraightRouting() {
        // An orthogonal edge's path bends through (300, 0) then down to
        // (300, 200) — a point directly between the two endpoints on a
        // straight diagonal would miss both segments, so this only passes
        // if hit-testing actually follows the routed (bent) path.
        let edge = DiagramEdge(source: .point(Point2D(x: 0, y: 0)), target: .point(Point2D(x: 300, y: 200)), routing: .orthogonal)
        let h = Harness()
        h.view.loadPage(page(nodes: [], edges: [edge]))

        h.click(at: CGPoint(x: 300, y: 100))
        XCTAssertEqual(h.view.edgeSelection, [edge.id], "should hit the vertical segment of the orthogonal bend")

        h.click(at: CGPoint(x: 150, y: 100))
        XCTAssertEqual(h.view.edgeSelection, [], "the midpoint of the straight-line diagonal is not on the orthogonal path")
    }

    func testApplyExternalEdgeSelectionUpdatesSelectionWithoutFiringCallback() {
        let (h, edge) = makeStraightEdgeFixture()
        var firedCount = 0
        h.view.onEdgeSelectionChange = { _ in firedCount += 1 }

        h.view.applyExternalEdgeSelection([edge.id])
        XCTAssertEqual(h.view.edgeSelection, [edge.id])
        XCTAssertEqual(firedCount, 0)
    }

    func testLoadPagePrunesEdgeSelectionOfRemovedEdges() {
        let (h, edge) = makeStraightEdgeFixture()
        h.view.applyExternalEdgeSelection([edge.id])
        XCTAssertEqual(h.view.edgeSelection, [edge.id])

        h.view.loadPage(page(nodes: [], edges: []))
        XCTAssertEqual(h.view.edgeSelection, [])
    }

    func testUpdateSelectedEdgesChangesRoutingOfSelectedEdgeOnly() {
        let edgeA = DiagramEdge(source: .point(Point2D(x: 0, y: 0)), target: .point(Point2D(x: 300, y: 0)), routing: .straight)
        let edgeB = DiagramEdge(source: .point(Point2D(x: 0, y: 400)), target: .point(Point2D(x: 300, y: 400)), routing: .straight)
        let h = Harness()
        h.view.loadPage(page(nodes: [], edges: [edgeA, edgeB]))
        h.view.applyExternalEdgeSelection([edgeA.id])

        h.view.updateSelectedEdges(actionName: "Set Routing") { $0.routing = .isometric }

        let snapshot = h.view.currentPageSnapshot(name: "Test", order: 0, canvasSize: nil, background: PageBackground())
        XCTAssertEqual(snapshot.edges[edgeA.id]?.routing, .isometric)
        XCTAssertEqual(snapshot.edges[edgeB.id]?.routing, .straight, "only the selected edge should have changed")
    }

    func testDeleteRemovesSelectedEdgeNotSelectedNode() {
        let node = DiagramNode(type: .rectangle, position: Point2D(x: 500, y: 500), size: Size2D(width: 100, height: 60))
        let edge = DiagramEdge(source: .point(Point2D(x: 0, y: 0)), target: .point(Point2D(x: 300, y: 0)), routing: .straight)
        let h = Harness()
        h.view.loadPage(page(nodes: [node], edges: [edge]))
        h.view.applyExternalEdgeSelection([edge.id])

        h.view.delete(nil)

        XCTAssertEqual(h.view.edgeSelection, [])
        XCTAssertTrue(h.view.selection.isEmpty)
    }

    /// Drives the actual drag-to-connect tool (select node A, press on its
    /// right-edge connector handle, drag onto node B, release) rather than
    /// calling `addEdge` — `addEdge` is the *programmatic* path used by
    /// callers that already know both endpoints and always takes an
    /// explicit `routing:` argument; only the interactive tool consults
    /// `defaultRoutingStyle`.
    func testNewConnectorsUseTheConfiguredDefaultRoutingStyle() {
        let a = DiagramNode(type: .rectangle, position: Point2D(x: 0, y: 0), size: Size2D(width: 100, height: 100))
        let b = DiagramNode(type: .rectangle, position: Point2D(x: 400, y: 0), size: Size2D(width: 100, height: 100))
        let h = Harness()
        h.view.loadPage(page(nodes: [a, b], edges: []))
        h.view.defaultRoutingStyle = .entityRelation

        h.click(at: CGPoint(x: 50, y: 50)) // select node A so its connector handles appear
        XCTAssertEqual(h.view.selection, [a.id])

        // Node A's frame is (0,0,100,100); the right-edge handle sits 18pt
        // past its right edge, vertically centered — see connectorHandleOffset.
        h.drag(from: CGPoint(x: 118, y: 50), to: CGPoint(x: 450, y: 50))

        let snapshot = h.view.currentPageSnapshot(name: "Test", order: 0, canvasSize: nil, background: PageBackground())
        let newEdges = snapshot.edges.values.filter { edge in
            if case .node(a.id, _) = edge.source, case .node(b.id, _) = edge.target { return true }
            return false
        }
        XCTAssertEqual(newEdges.count, 1)
        XCTAssertEqual(newEdges.first?.routing, .entityRelation)
    }
}
