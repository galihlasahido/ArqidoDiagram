import XCTest
import DiagramModel
@testable import DiagramLayout

final class LayoutEngineTests: XCTestCase {
    private func makeNode(x: Double, y: Double, width: Double = 120, height: Double = 80) -> DiagramNode {
        DiagramNode(type: .rectangle, position: Point2D(x: x, y: y), size: Size2D(width: width, height: height))
    }

    private func makePage(nodes: [DiagramNode], edges: [DiagramEdge] = []) -> DiagramPage {
        var page = DiagramPage(name: "Test", order: 0)
        for node in nodes { page.nodes[node.id] = node }
        page.nodeZOrder = nodes.map(\.id)
        for edge in edges { page.edges[edge.id] = edge }
        page.edgeZOrder = edges.map(\.id)
        return page
    }

    // MARK: - Grid

    func testGridLayoutSpreadsNodesAcrossDistinctCells() {
        let nodes = (0..<6).map { makeNode(x: Double($0) * 5, y: 0) }
        let page = makePage(nodes: nodes)
        let laidOut = GridLayoutEngine().layout(page)

        let positions = Set(laidOut.nodes.values.map { "\($0.position.x),\($0.position.y)" })
        XCTAssertEqual(positions.count, nodes.count, "every node should land on a distinct grid cell")
    }

    func testGridLayoutOnEmptyPageIsANoOp() {
        let page = makePage(nodes: [])
        let laidOut = GridLayoutEngine().layout(page)
        XCTAssertTrue(laidOut.nodes.isEmpty)
    }

    // MARK: - Orthogonal

    func testOrthogonalLayoutSetsEveryEdgeToOrthogonalRouting() {
        let a = makeNode(x: 0, y: 0)
        let b = makeNode(x: 300, y: 0)
        let edge = DiagramEdge(source: .node(a.id, portID: nil), target: .node(b.id, portID: nil), routing: .straight)
        let page = makePage(nodes: [a, b], edges: [edge])

        let laidOut = OrthogonalLayoutEngine().layout(page)
        XCTAssertEqual(laidOut.edges[edge.id]?.routing, .orthogonal)
    }

    // MARK: - Hierarchical

    func testHierarchicalLayoutPlacesChildrenBelowParents() {
        let root = makeNode(x: 0, y: 0)
        let child = makeNode(x: 0, y: 0)
        let grandchild = makeNode(x: 0, y: 0)
        let edges = [
            DiagramEdge(source: .node(root.id, portID: nil), target: .node(child.id, portID: nil)),
            DiagramEdge(source: .node(child.id, portID: nil), target: .node(grandchild.id, portID: nil))
        ]
        let page = makePage(nodes: [root, child, grandchild], edges: edges)

        let laidOut = HierarchicalLayoutEngine().layout(page)
        let rootY = laidOut.nodes[root.id]!.position.y
        let childY = laidOut.nodes[child.id]!.position.y
        let grandchildY = laidOut.nodes[grandchild.id]!.position.y
        XCTAssertLessThan(rootY, childY)
        XCTAssertLessThan(childY, grandchildY)
    }

    func testHierarchicalLayoutTerminatesOnACycle() {
        let a = makeNode(x: 0, y: 0)
        let b = makeNode(x: 0, y: 0)
        let edges = [
            DiagramEdge(source: .node(a.id, portID: nil), target: .node(b.id, portID: nil)),
            DiagramEdge(source: .node(b.id, portID: nil), target: .node(a.id, portID: nil))
        ]
        let page = makePage(nodes: [a, b], edges: edges)

        // Only needs to return without hanging/crashing — a cyclic graph
        // has no "correct" layering, just a bounded, deterministic one.
        let laidOut = HierarchicalLayoutEngine().layout(page)
        XCTAssertEqual(laidOut.nodes.count, 2)
    }

    // MARK: - Tree

    func testTreeLayoutCentersParentOverItsChildren() {
        let root = makeNode(x: 0, y: 0)
        let left = makeNode(x: 0, y: 0)
        let right = makeNode(x: 0, y: 0)
        let edges = [
            DiagramEdge(source: .node(root.id, portID: nil), target: .node(left.id, portID: nil)),
            DiagramEdge(source: .node(root.id, portID: nil), target: .node(right.id, portID: nil))
        ]
        let page = makePage(nodes: [root, left, right], edges: edges)

        let laidOut = TreeLayoutEngine().layout(page)
        let rootCenterX = laidOut.nodes[root.id]!.position.x + laidOut.nodes[root.id]!.size.width / 2
        let leftCenterX = laidOut.nodes[left.id]!.position.x + laidOut.nodes[left.id]!.size.width / 2
        let rightCenterX = laidOut.nodes[right.id]!.position.x + laidOut.nodes[right.id]!.size.width / 2
        XCTAssertEqual(rootCenterX, (leftCenterX + rightCenterX) / 2, accuracy: 0.01)
    }

    // MARK: - Circular

    func testCircularLayoutKeepsEveryNodeAtRoughlyEqualDistanceFromCenter() {
        let nodes = (0..<8).map { _ in makeNode(x: 0, y: 0) }
        let page = makePage(nodes: nodes)

        let laidOut = CircularLayoutEngine().layout(page)
        let centers = laidOut.nodes.values.map { node in
            (x: node.position.x + node.size.width / 2, y: node.position.y + node.size.height / 2)
        }
        let distances = centers.map { (($0.x * $0.x) + ($0.y * $0.y)).squareRoot() }
        let maxDistance = distances.max()!
        let minDistance = distances.min()!
        XCTAssertEqual(maxDistance, minDistance, accuracy: 0.5)
    }

    // MARK: - Force-directed

    func testForceDirectedLayoutSeparatesInitiallyCoincidentNodes() {
        let nodes = (0..<5).map { _ in makeNode(x: 400, y: 400) }
        let page = makePage(nodes: nodes)

        let laidOut = ForceDirectedLayoutEngine().layout(page)
        let positions = laidOut.nodes.values.map { "\(($0.position.x * 10).rounded()),\(($0.position.y * 10).rounded())" }
        XCTAssertEqual(Set(positions).count, nodes.count, "force simulation should push coincident nodes apart")
    }

    func testForceDirectedLayoutOnASingleNodeIsANoOp() {
        let page = makePage(nodes: [makeNode(x: 50, y: 50)])
        let laidOut = ForceDirectedLayoutEngine().layout(page)
        XCTAssertEqual(laidOut.nodes.first?.value.position.x, 50)
        XCTAssertEqual(laidOut.nodes.first?.value.position.y, 50)
    }
}
