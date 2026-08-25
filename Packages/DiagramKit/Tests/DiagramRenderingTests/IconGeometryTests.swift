import XCTest
import DiagramModel
@testable import DiagramRendering

final class IconGeometryTests: XCTestCase {
    private let rect = CGRect(x: 0, y: 0, width: 28, height: 28)

    func testEveryTechIconTypeProducesANonEmptyPathWithinItsBounds() {
        for type in TechIconType.allCases {
            let path = IconGeometry.path(for: type, in: rect)
            XCTAssertFalse(path.isEmpty, "\(type) produced an empty path")

            let bbox = path.boundingBoxOfPath
            XCTAssertTrue(rect.insetBy(dx: -4, dy: -4).contains(bbox), "\(type) path escaped its bounds: \(bbox)")
        }
    }
}
