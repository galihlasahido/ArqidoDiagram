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

    func testEntityRelationPathStaysWithinTheAxisAlignedBoundingBoxAndEndsAtTarget() {
        let source = CGPoint(x: 0, y: 0)
        let target = CGPoint(x: 100, y: 50)
        let path = EdgeGeometry.path(from: source, to: target, routing: .entityRelation)
        XCTAssertEqual(path.boundingBoxOfPath, CGRect(x: 0, y: 0, width: 100, height: 50))
        XCTAssertEqual(path.currentPoint, target)
    }

    func testEntityRelationPathJogsAtTheHorizontalMidpoint() {
        let source = CGPoint(x: 0, y: 0)
        let target = CGPoint(x: 100, y: 50)
        let path = EdgeGeometry.path(from: source, to: target, routing: .entityRelation)
        var points: [CGPoint] = []
        path.applyWithBlock { element in
            if element.pointee.type != .closeSubpath {
                points.append(element.pointee.points.pointee)
            }
        }
        // move, line-to-(mid,source.y), line-to-(mid,target.y), line-to-target
        XCTAssertEqual(points.count, 4)
        XCTAssertEqual(points[1], CGPoint(x: 50, y: 0))
        XCTAssertEqual(points[2], CGPoint(x: 50, y: 50))
    }

    func testIsometricPathEndsExactlyAtTarget() {
        let source = CGPoint(x: 10, y: 20)
        let target = CGPoint(x: 130, y: -40)
        let path = EdgeGeometry.path(from: source, to: target, routing: .isometric)
        XCTAssertEqual(path.currentPoint.x, target.x, accuracy: 0.01)
        XCTAssertEqual(path.currentPoint.y, target.y, accuracy: 0.01)
    }

    func testIsometricPathSegmentsFollowTheIsometricAxes() {
        let source = CGPoint(x: 0, y: 0)
        let target = CGPoint(x: 120, y: 30)
        let path = EdgeGeometry.path(from: source, to: target, routing: .isometric)
        var points: [CGPoint] = []
        path.applyWithBlock { element in
            if element.pointee.type != .closeSubpath {
                points.append(element.pointee.points.pointee)
            }
        }
        XCTAssertEqual(points.count, 3)
        let bend = points[1]
        // Segment 1 (source -> bend) must lie on axis A = (2,1): slope 0.5.
        XCTAssertEqual((bend.y - source.y) / (bend.x - source.x), 0.5, accuracy: 0.0001)
        // Segment 2 (bend -> target) must lie on axis B = (2,-1): slope -0.5.
        XCTAssertEqual((target.y - bend.y) / (target.x - bend.x), -0.5, accuracy: 0.0001)
    }

    func testResolvedEndpointsForNodeToNodeEdge() throws {
        let a = DiagramNode(type: .rectangle, position: Point2D(x: 0, y: 0), size: Size2D(width: 100, height: 100))
        let b = DiagramNode(type: .rectangle, position: Point2D(x: 300, y: 0), size: Size2D(width: 100, height: 100))
        let nodes = [a.id: a, b.id: b]
        let edge = DiagramEdge(source: .node(a.id, portID: nil), target: .node(b.id, portID: nil))

        let resolved = try XCTUnwrap(EdgeGeometry.resolvedEndpoints(for: edge, nodes: nodes))
        XCTAssertEqual(resolved.source.x, 100, accuracy: 0.01, "should exit A's right edge, towards B")
        XCTAssertEqual(resolved.target.x, 300, accuracy: 0.01, "should enter B's left edge, coming from A")
    }

    func testResolvedEndpointsIsNilWhenANodeEndpointIsMissing() {
        let edge = DiagramEdge(source: .node(NodeID(), portID: nil), target: .point(Point2D(x: 0, y: 0)))
        XCTAssertNil(EdgeGeometry.resolvedEndpoints(for: edge, nodes: [:]))
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
