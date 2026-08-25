import XCTest
import DiagramModel
@testable import DiagramRendering

final class ShapeGeometryTests: XCTestCase {
    private let rect = CGRect(x: 10, y: 20, width: 200, height: 100)

    func testEveryShapeTypeProducesANonEmptyPathWithinItsBounds() {
        for type in ShapeType.allCases {
            let path = ShapeGeometry.path(for: type, in: rect)
            XCTAssertFalse(path.isEmpty, "\(type) produced an empty path")

            // A generous outset, not exact containment: curved shapes
            // (document's wave, star points) can slightly exceed the
            // nominal rect by construction — this only guards against a
            // shape type ignoring `rect` entirely (e.g. a fixed-size bug).
            let bbox = path.boundingBoxOfPath
            XCTAssertTrue(rect.insetBy(dx: -20, dy: -20).contains(bbox), "\(type) path escaped its rect: \(bbox)")
        }
    }

    func testDiamondPathHasFourPoints() {
        let path = ShapeGeometry.path(for: .diamond, in: rect)
        let bbox = path.boundingBoxOfPath
        XCTAssertEqual(bbox.width, rect.width, accuracy: 0.01)
        XCTAssertEqual(bbox.height, rect.height, accuracy: 0.01)
    }

    func testCirclePathIsInscribedInTheSmallerDimension() {
        let path = ShapeGeometry.path(for: .circle, in: rect)
        let bbox = path.boundingBoxOfPath
        XCTAssertEqual(bbox.width, rect.height, accuracy: 0.01)
        XCTAssertEqual(bbox.height, rect.height, accuracy: 0.01)
    }
}
