import XCTest
@testable import DiagramRendering

final class CanvasViewportTests: XCTestCase {
    func testViewToContentInvertsContentToView() {
        let viewport = CanvasViewport(scale: 2, contentOrigin: CGPoint(x: 100, y: 50))
        let contentPoint = CGPoint(x: 300, y: 200)
        let viewPoint = contentPoint.applying(viewport.contentToViewTransform)
        let roundTripped = viewport.viewToContent(point: viewPoint)

        XCTAssertEqual(roundTripped.x, contentPoint.x, accuracy: 0.0001)
        XCTAssertEqual(roundTripped.y, contentPoint.y, accuracy: 0.0001)
    }

    func testOriginMapsToNegativeOriginTimesScale() {
        let viewport = CanvasViewport(scale: 2, contentOrigin: CGPoint(x: 100, y: 50))
        let viewPoint = CGPoint.zero.applying(viewport.contentToViewTransform)
        XCTAssertEqual(viewPoint, CGPoint(x: -200, y: -100))
    }

    func testFittingCentersContentAndFillsAvailableSpace() {
        let viewport = CanvasViewport.fitting(
            contentBounds: CGRect(x: 0, y: 0, width: 1000, height: 500),
            viewSize: CGSize(width: 1200, height: 800),
            padding: 0
        )
        // Width is the binding dimension: 1200 / 1000 = 1.2 (< 800 / 500 = 1.6).
        XCTAssertEqual(viewport.scale, 1.2, accuracy: 0.0001)

        let contentCenter = CGPoint(x: 500, y: 250)
        let viewPoint = contentCenter.applying(viewport.contentToViewTransform)
        XCTAssertEqual(viewPoint.x, 600, accuracy: 0.01)
        XCTAssertEqual(viewPoint.y, 400, accuracy: 0.01)
    }

    func testFittingClampsToMaxScaleForTinyContent() {
        let viewport = CanvasViewport.fitting(
            contentBounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            viewSize: CGSize(width: 1000, height: 1000),
            padding: 0
        )
        XCTAssertEqual(viewport.scale, CanvasViewport.maxScale)
    }
}
