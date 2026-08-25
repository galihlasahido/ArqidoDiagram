import XCTest
import DiagramModel
@testable import DiagramRendering

final class PresentationControllerTests: XCTestCase {
    private func makeFrames(count: Int) -> [PresentationFrame] {
        let pageID = PageID()
        return (0..<count).map { i in
            PresentationFrame(
                pageID: pageID,
                name: "Frame \(i)",
                rect: Rect2D(origin: Point2D(x: Double(i) * 100, y: 0), size: Size2D(width: 400, height: 300))
            )
        }
    }

    func testNextAdvancesAndStopsAtLastFrame() {
        var controller = PresentationController(frames: makeFrames(count: 3))
        XCTAssertEqual(controller.currentIndex, 0)
        controller.next()
        XCTAssertEqual(controller.currentIndex, 1)
        controller.next()
        XCTAssertEqual(controller.currentIndex, 2)
        XCTAssertFalse(controller.hasNext)
        controller.next()
        XCTAssertEqual(controller.currentIndex, 2, "next() past the last frame should be a no-op")
    }

    func testPreviousRetreatsAndStopsAtFirstFrame() {
        var controller = PresentationController(frames: makeFrames(count: 3), startIndex: 2)
        controller.previous()
        XCTAssertEqual(controller.currentIndex, 1)
        controller.previous()
        XCTAssertEqual(controller.currentIndex, 0)
        XCTAssertFalse(controller.hasPrevious)
        controller.previous()
        XCTAssertEqual(controller.currentIndex, 0, "previous() before the first frame should be a no-op")
    }

    func testZoomInIncreasesMultiplierAndClampsAtMax() {
        var controller = PresentationController(frames: makeFrames(count: 1))
        controller.zoomIn(step: 2)
        XCTAssertEqual(controller.zoomMultiplier, 2)
        for _ in 0..<10 { controller.zoomIn(step: 2) }
        XCTAssertEqual(controller.zoomMultiplier, PresentationController.maxZoomMultiplier)
    }

    func testZoomOutDecreasesMultiplierAndClampsAtMin() {
        var controller = PresentationController(frames: makeFrames(count: 1))
        controller.zoomOut(step: 2)
        XCTAssertEqual(controller.zoomMultiplier, 0.5)
        for _ in 0..<10 { controller.zoomOut(step: 2) }
        XCTAssertEqual(controller.zoomMultiplier, PresentationController.minZoomMultiplier)
    }

    func testAdvancingFramesResetsZoom() {
        var controller = PresentationController(frames: makeFrames(count: 2))
        controller.zoomIn(step: 3)
        XCTAssertEqual(controller.zoomMultiplier, 3)
        controller.next()
        XCTAssertEqual(controller.zoomMultiplier, 1)
    }

    func testToggleFocusFlipsState() {
        var controller = PresentationController(frames: makeFrames(count: 1))
        XCTAssertFalse(controller.isFocusModeOn)
        controller.toggleFocus()
        XCTAssertTrue(controller.isFocusModeOn)
    }

    func testActiveFocusNodeIDsIsNilWhenFocusOffOrFrameHasNoFocusSet() {
        var controller = PresentationController(frames: makeFrames(count: 1))
        XCTAssertNil(controller.activeFocusNodeIDs)
        controller.toggleFocus()
        XCTAssertNil(controller.activeFocusNodeIDs, "no focusNodeIDs on the frame means nothing to dim")
    }

    func testActiveFocusNodeIDsReturnsFrameSetWhenFocusOn() {
        let nodeID = NodeID()
        let frame = PresentationFrame(
            pageID: PageID(),
            name: "Focused",
            rect: Rect2D(origin: .init(x: 0, y: 0), size: .init(width: 100, height: 100)),
            focusNodeIDs: [nodeID]
        )
        var controller = PresentationController(frames: [frame])
        controller.toggleFocus()
        XCTAssertEqual(controller.activeFocusNodeIDs, [nodeID])
    }

    func testJumpToValidIndexResetsZoomAndIgnoresOutOfRange() {
        var controller = PresentationController(frames: makeFrames(count: 3))
        controller.zoomIn()
        controller.jump(to: 2)
        XCTAssertEqual(controller.currentIndex, 2)
        XCTAssertEqual(controller.zoomMultiplier, 1)
        controller.jump(to: 99)
        XCTAssertEqual(controller.currentIndex, 2, "an out-of-range jump should be a no-op")
    }

    func testViewportFitsCurrentFrameRectAndAppliesZoomMultiplier() throws {
        let frame = PresentationFrame(
            pageID: PageID(),
            name: "Slide",
            rect: Rect2D(origin: .init(x: 0, y: 0), size: .init(width: 400, height: 300))
        )
        var controller = PresentationController(frames: [frame])
        let baseViewport = try XCTUnwrap(controller.viewport(for: CGSize(width: 800, height: 600)))
        XCTAssertEqual(baseViewport.scale, 2, accuracy: 0.0001, "800/400 == 600/300 == 2, and there's no padding to shrink it")

        controller.zoomIn(step: 2)
        let zoomedViewport = try XCTUnwrap(controller.viewport(for: CGSize(width: 800, height: 600)))
        XCTAssertEqual(zoomedViewport.scale, 4, accuracy: 0.0001)
    }

    func testEmptyFramesYieldsNilCurrentFrameAndViewport() {
        let controller = PresentationController(frames: [])
        XCTAssertNil(controller.currentFrame)
        XCTAssertNil(controller.viewport(for: CGSize(width: 800, height: 600)))
    }
}
