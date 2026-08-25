import XCTest
import DiagramModel
@testable import DiagramRendering

final class EdgeGeometryTests: XCTestCase {
    func testClippedPointExitsOnTheCorrectEdge() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let center = rect.center

        let right = EdgeGeometry.clippedPoint(from: center, towards: CGPoint(x: 1000, y: 50), in: rect)
        XCTAssertEqual(right.x, 100, accuracy: 0.01)

        let bottom = EdgeGeometry.clippedPoint(from: center, towards: CGPoint(x: 50, y: 1000), in: rect)
        XCTAssertEqual(bottom.y, 100, accuracy: 0.01)
    }

    func testResolvedPointForNodeEndpoint() throws {
        let node = DiagramNode(type: .rectangle, position: Point2D(x: 0, y: 0), size: Size2D(width: 100, height: 100))
        let nodes = [node.id: node]

        let point = try XCTUnwrap(EdgeGeometry.resolvedPoint(for: .node(node.id, portID: nil), nodes: nodes, towards: CGPoint(x: 1000, y: 50)))
        XCTAssertEqual(point.x, 100, accuracy: 0.01)
    }

    func testResolvedPointForMissingNodeIsNil() {
        let point = EdgeGeometry.resolvedPoint(for: .node(NodeID(), portID: nil), nodes: [:], towards: .zero)
        XCTAssertNil(point)
    }

    func testResolvedPointForDanglingPointEndpoint() {
        let point = EdgeGeometry.resolvedPoint(for: .point(Point2D(x: 42, y: 7)), nodes: [:], towards: .zero)
        XCTAssertEqual(point, CGPoint(x: 42, y: 7))
    }

    func testStraightPathIsTwoPoints() {
        let path = EdgeGeometry.path(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 100, y: 100), routing: .straight)
        XCTAssertEqual(path.boundingBoxOfPath, CGRect(x: 0, y: 0, width: 100, height: 100))
    }

    func testOrthogonalPathStaysWithinTheAxisAlignedBoundingBox() {
        let path = EdgeGeometry.path(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 100, y: 50), routing: .orthogonal)
        XCTAssertEqual(path.boundingBoxOfPath, CGRect(x: 0, y: 0, width: 100, height: 50))
    }

    func testNoneArrowheadIsNil() {
        XCTAssertNil(EdgeGeometry.arrowheadPath(from: .zero, tip: CGPoint(x: 10, y: 0), style: .none))
    }

    func testFilledArrowheadPointsAtTip() throws {
        let tip = CGPoint(x: 100, y: 0)
        let path = try XCTUnwrap(EdgeGeometry.arrowheadPath(from: .zero, tip: tip, style: .filled, size: 10))
        XCTAssertEqual(path.boundingBoxOfPath.maxX, tip.x, accuracy: 0.01, "the arrowhead's bounding box should reach exactly to the tip")
    }
}
