import XCTest
import AppKit
import DiagramModel
@testable import DiagramRendering

/// Exercises real mouse interaction (click, marquee, move, resize, rotate)
/// via synthetic, in-process `NSEvent`s against an offscreen `NSWindow` —
/// never a real screen click. This is deliberate: driving the actual app
/// with screen-coordinate automation risks hitting whatever window happens
/// to be at that point on the real display (another app, another terminal),
/// which is exactly the kind of risk synthetic in-process events avoid
/// entirely. The window is created but never ordered front/shown.
private final class Harness {
    let window: NSWindow
    let view: DiagramCanvasView

    init(frame: NSRect = NSRect(x: 0, y: 0, width: 1000, height: 800)) {
        window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: true)
        view = DiagramCanvasView(frame: frame)
        window.contentView = view
        // Fixed 1:1 viewport (not fit-to-screen) so view-space coordinates
        // in tests equal content-space coordinates directly.
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

final class DiagramCanvasViewInteractionTests: XCTestCase {
    private func makeNode(x: Double = 100, y: Double = 100, w: Double = 100, h: Double = 60) -> DiagramNode {
        DiagramNode(type: .rectangle, position: Point2D(x: x, y: y), size: Size2D(width: w, height: h))
    }

    private func page(with nodes: [DiagramNode]) -> DiagramPage {
        var page = DiagramPage(name: "Test", order: 0)
        for node in nodes {
            page.nodes[node.id] = node
            page.nodeZOrder.append(node.id)
        }
        return page
    }

    // MARK: - Loading / pruning

    func testApplyExternalSelectionUpdatesSelection() {
        let h = Harness()
        let node = makeNode()
        h.view.loadPage(page(with: [node]))

        h.view.applyExternalSelection([node.id])
        XCTAssertEqual(h.view.selection, [node.id])

        h.view.applyExternalSelection([])
        XCTAssertEqual(h.view.selection, [])
    }

    func testApplyExternalSelectionDoesNotFireOnSelectionChange() {
        let h = Harness()
        let node = makeNode()
        h.view.loadPage(page(with: [node]))

        var firedCount = 0
        h.view.onSelectionChange = { _ in firedCount += 1 }
        h.view.applyExternalSelection([node.id])

        XCTAssertEqual(firedCount, 0)
    }

    func testLoadPagePrunesSelectionOfRemovedNodes() {
        let h = Harness()
        let nodeA = makeNode()
        let nodeB = makeNode(x: 400)
        h.view.loadPage(page(with: [nodeA, nodeB]))
        h.view.applyExternalSelection([nodeA.id, nodeB.id])

        h.view.loadPage(page(with: [nodeB]))

        XCTAssertEqual(h.view.selection, [nodeB.id])
    }

    func testNodeCountReflectsLoadedNodes() {
        let h = Harness()
        XCTAssertEqual(h.view.nodeCount, 0)
        h.view.loadPage(page(with: [makeNode(), makeNode(x: 300), makeNode(x: 600)]))
        XCTAssertEqual(h.view.nodeCount, 3)
    }

    // MARK: - Click-to-select

    func testClickInsideShapeSelectsIt() {
        let h = Harness()
        let node = makeNode(x: 100, y: 100, w: 100, h: 60)
        h.view.loadPage(page(with: [node]))

        h.click(at: CGPoint(x: 150, y: 130)) // center of the node
        XCTAssertEqual(h.view.selection, [node.id])
    }

    func testClickOnEmptySpaceDeselects() {
        let h = Harness()
        let node = makeNode()
        h.view.loadPage(page(with: [node]))
        h.view.applyExternalSelection([node.id])

        h.click(at: CGPoint(x: 900, y: 700))
        XCTAssertEqual(h.view.selection, [])
    }

    func testShiftClickTogglesSelection() {
        let h = Harness()
        let nodeA = makeNode(x: 0, y: 0, w: 100, h: 60)
        let nodeB = makeNode(x: 300, y: 0, w: 100, h: 60)
        h.view.loadPage(page(with: [nodeA, nodeB]))

        h.click(at: CGPoint(x: 50, y: 30))
        h.click(at: CGPoint(x: 350, y: 30), modifiers: .shift)
        XCTAssertEqual(h.view.selection, [nodeA.id, nodeB.id])

        h.click(at: CGPoint(x: 50, y: 30), modifiers: .shift)
        XCTAssertEqual(h.view.selection, [nodeB.id])
    }

    func testTopmostNodeByZIndexIsSelectedWhenOverlapping() {
        let h = Harness()
        var back = makeNode(x: 100, y: 100, w: 100, h: 100)
        back.zIndex = 0
        var front = makeNode(x: 100, y: 100, w: 100, h: 100)
        front.zIndex = 1
        h.view.loadPage(page(with: [back, front]))

        h.click(at: CGPoint(x: 150, y: 150))
        XCTAssertEqual(h.view.selection, [front.id])
    }

    // MARK: - Marquee

    func testMarqueeDragSelectsIntersectingNodes() {
        let h = Harness()
        let inside = makeNode(x: 50, y: 50, w: 50, h: 50)
        let outside = makeNode(x: 900, y: 700, w: 50, h: 50)
        h.view.loadPage(page(with: [inside, outside]))

        h.drag(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 200, y: 200))
        XCTAssertEqual(h.view.selection, [inside.id])
    }

    // MARK: - Move

    func testDragMoveUpdatesNodePosition() {
        let h = Harness()
        let node = makeNode(x: 100, y: 100, w: 100, h: 60)
        h.view.loadPage(page(with: [node]))
        h.view.applyExternalSelection([node.id])

        h.drag(from: CGPoint(x: 150, y: 130), to: CGPoint(x: 250, y: 230))

        // Assert indirectly through the public surface: after moving by
        // (+100, +100), the node's new center (250, 230) should hit-test to
        // it, and its old center (150, 130) should no longer.
        h.view.applyExternalSelection([])
        h.click(at: CGPoint(x: 250, y: 230))
        XCTAssertEqual(h.view.selection, [node.id])

        h.view.applyExternalSelection([])
        h.click(at: CGPoint(x: 150, y: 130))
        XCTAssertEqual(h.view.selection, [], "the old location should no longer hit the moved node")
    }

    func testDragMoveIsUndoableToExactStartingPosition() {
        let h = Harness()
        let node = makeNode(x: 100, y: 100, w: 100, h: 60)
        h.view.loadPage(page(with: [node]))
        h.view.applyExternalSelection([node.id])
        let undoManager = UndoManager()
        h.view.documentUndoManager = undoManager

        h.drag(from: CGPoint(x: 150, y: 130), to: CGPoint(x: 250, y: 230))
        XCTAssertTrue(undoManager.canUndo)

        undoManager.undo()
        // After undo, clicking at the ORIGINAL location should hit it again.
        h.view.applyExternalSelection([])
        h.click(at: CGPoint(x: 150, y: 130))
        XCTAssertEqual(h.view.selection, [node.id])
    }

    func testTinyDragDoesNotRegisterAnUndoStep() {
        let h = Harness()
        let node = makeNode(x: 100, y: 100, w: 100, h: 60)
        h.view.loadPage(page(with: [node]))
        h.view.applyExternalSelection([node.id])
        let undoManager = UndoManager()
        h.view.documentUndoManager = undoManager

        h.drag(from: CGPoint(x: 150, y: 130), to: CGPoint(x: 150, y: 130))
        XCTAssertFalse(undoManager.canUndo, "a zero-distance drag shouldn't register a no-op undo step")
    }

    // MARK: - Add / delete / duplicate

    func testAddNodeInsertsAndSelectsIt() {
        let h = Harness()
        h.view.loadPage(page(with: []))

        let id = h.view.addNode(ofType: .ellipse, at: CGPoint(x: 400, y: 300))
        XCTAssertEqual(h.view.nodeCount, 1)
        XCTAssertEqual(h.view.selection, [id])
    }

    func testDeleteRemovesSelectedNodes() {
        let h = Harness()
        let node = makeNode()
        h.view.loadPage(page(with: [node]))
        h.view.applyExternalSelection([node.id])

        h.view.delete(nil)
        XCTAssertEqual(h.view.nodeCount, 0)
        XCTAssertEqual(h.view.selection, [])
    }

    func testDeleteIsUndoable() {
        let h = Harness()
        let node = makeNode()
        h.view.loadPage(page(with: [node]))
        h.view.applyExternalSelection([node.id])
        let undoManager = UndoManager()
        h.view.documentUndoManager = undoManager

        h.view.delete(nil)
        XCTAssertEqual(h.view.nodeCount, 0)
        undoManager.undo()
        XCTAssertEqual(h.view.nodeCount, 1)
    }

    func testDuplicateAddsOffsetCopyAndSelectsIt() {
        let h = Harness()
        let node = makeNode(x: 100, y: 100)
        h.view.loadPage(page(with: [node]))
        h.view.applyExternalSelection([node.id])

        h.view.duplicate(nil)
        XCTAssertEqual(h.view.nodeCount, 2)
        XCTAssertFalse(h.view.selection.contains(node.id), "duplicate should select the new copy, not the original")
    }

    // MARK: - Resize

    func testDragCornerHandleResizesSingleSelection() {
        let h = Harness()
        let node = makeNode(x: 100, y: 100, w: 100, h: 100)
        h.view.loadPage(page(with: [node]))
        h.view.applyExternalSelection([node.id])

        // Bottom-right handle sits at the node's bottom-right corner (200, 200).
        h.drag(from: CGPoint(x: 200, y: 200), to: CGPoint(x: 300, y: 260))

        h.view.applyExternalSelection([])
        // The resized node's bottom-right is now (300, 260); its top-left
        // (100, 100) is unaffected — probe a point only reachable if width
        // actually grew past the original 200 boundary.
        h.click(at: CGPoint(x: 250, y: 150))
        XCTAssertEqual(h.view.selection, [node.id])
    }

    // MARK: - Z-order

    func testBringForwardSwapsHitTestOrderWithOverlappingNeighbor() {
        let h = Harness()
        var back = makeNode(x: 100, y: 100, w: 100, h: 100)
        back.zIndex = 0
        var front = makeNode(x: 100, y: 100, w: 100, h: 100)
        front.zIndex = 1
        h.view.loadPage(page(with: [back, front]))

        h.click(at: CGPoint(x: 150, y: 150))
        XCTAssertEqual(h.view.selection, [front.id], "sanity check: front is on top before any reordering")

        h.view.applyExternalSelection([back.id])
        h.view.bringForward(nil)

        h.view.applyExternalSelection([])
        h.click(at: CGPoint(x: 150, y: 150))
        XCTAssertEqual(h.view.selection, [back.id], "bringForward should have swapped back above front")
    }

    // MARK: - Select all

    func testSelectAllSelectsEveryNode() {
        let h = Harness()
        let a = makeNode(x: 0)
        let b = makeNode(x: 300)
        h.view.loadPage(page(with: [a, b]))

        h.view.selectAll(nil)
        XCTAssertEqual(h.view.selection, [a.id, b.id])
    }

    // MARK: - Group / ungroup

    func testGroupSelectionThenClickingOneMemberSelectsWholeGroup() {
        let h = Harness()
        let a = makeNode(x: 0, y: 0, w: 100, h: 60)
        let b = makeNode(x: 300, y: 0, w: 100, h: 60)
        h.view.loadPage(page(with: [a, b]))
        h.view.applyExternalSelection([a.id, b.id])

        h.view.groupSelection(nil)

        h.view.applyExternalSelection([])
        h.click(at: CGPoint(x: 50, y: 30)) // inside `a` only
        XCTAssertEqual(h.view.selection, [a.id, b.id], "clicking one grouped member should select the whole group")
    }

    func testUngroupRestoresIndependentSelection() {
        let h = Harness()
        let a = makeNode(x: 0, y: 0, w: 100, h: 60)
        let b = makeNode(x: 300, y: 0, w: 100, h: 60)
        h.view.loadPage(page(with: [a, b]))
        h.view.applyExternalSelection([a.id, b.id])
        h.view.groupSelection(nil)

        h.view.applyExternalSelection([a.id, b.id])
        h.view.ungroupSelection(nil)

        h.view.applyExternalSelection([])
        h.click(at: CGPoint(x: 50, y: 30))
        XCTAssertEqual(h.view.selection, [a.id], "after ungrouping, clicking one member should select only that node")
    }

    func testGroupUngroupRoundTripIsUndoable() {
        let h = Harness()
        let a = makeNode(x: 0, y: 0, w: 100, h: 60)
        let b = makeNode(x: 300, y: 0, w: 100, h: 60)
        h.view.loadPage(page(with: [a, b]))
        h.view.applyExternalSelection([a.id, b.id])
        let undoManager = UndoManager()
        h.view.documentUndoManager = undoManager

        h.view.groupSelection(nil)
        XCTAssertTrue(undoManager.canUndo)
        undoManager.undo()

        h.view.applyExternalSelection([])
        h.click(at: CGPoint(x: 50, y: 30))
        XCTAssertEqual(h.view.selection, [a.id], "undoing Group should ungroup again")
    }

    // MARK: - Cut

    func testCutCopiesToPasteboardAndDeletes() {
        let h = Harness()
        let node = makeNode()
        h.view.loadPage(page(with: [node]))
        h.view.applyExternalSelection([node.id])

        h.view.cut(nil)
        XCTAssertEqual(h.view.nodeCount, 0)

        h.view.paste(nil)
        XCTAssertEqual(h.view.nodeCount, 1, "cut should have left a pasteable copy on the pasteboard")
    }
}
