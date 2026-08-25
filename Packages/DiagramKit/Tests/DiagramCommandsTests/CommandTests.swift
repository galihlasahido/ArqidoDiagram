import XCTest
import DiagramModel
@testable import DiagramCommands

final class CommandTests: XCTestCase {
    private func makeScene(with nodes: [DiagramNode] = []) -> SceneStore {
        var page = DiagramPage(name: "Test", order: 0)
        for node in nodes {
            page.nodes[node.id] = node
            page.nodeZOrder.append(node.id)
        }
        return SceneStore(page: page)
    }

    private func makeNode(x: Double = 0, y: Double = 0) -> DiagramNode {
        DiagramNode(type: .rectangle, position: Point2D(x: x, y: y), size: Size2D(width: 100, height: 60))
    }

    func testUpdateNodesCommandAppliesAndInverts() {
        let node = makeNode()
        let scene = makeScene(with: [node])

        var moved = node
        moved.position = Point2D(x: 200, y: 300)
        let command = UpdateNodesCommand(before: [node.id: node], after: [node.id: moved])

        command.apply(to: scene)
        XCTAssertEqual(scene.nodes[node.id]?.position.x, 200)

        command.inverse().apply(to: scene)
        XCTAssertEqual(scene.nodes[node.id]?.position.x, 0)
    }

    func testAddNodesCommandInverseRemoves() {
        let scene = makeScene()
        let node = makeNode()
        let command = AddNodesCommand(nodes: [node])

        command.apply(to: scene)
        XCTAssertNotNil(scene.nodes[node.id])

        command.inverse().apply(to: scene)
        XCTAssertNil(scene.nodes[node.id])
    }

    func testRemoveNodesCommandInverseRestoresExactNode() {
        let node = makeNode(x: 42, y: 7)
        let scene = makeScene(with: [node])
        let command = RemoveNodesCommand(nodes: [node])

        command.apply(to: scene)
        XCTAssertNil(scene.nodes[node.id])

        command.inverse().apply(to: scene)
        XCTAssertEqual(scene.nodes[node.id], node)
    }

    func testGroupAndUngroupRoundTrip() {
        let nodeA = makeNode()
        let nodeB = makeNode(x: 200)
        let scene = makeScene(with: [nodeA, nodeB])
        let group = DiagramGroup(memberNodeIDs: [nodeA.id, nodeB.id])
        let command = GroupNodesCommand(group: group, previousGroupIDs: [nodeA.id: nil, nodeB.id: nil])

        command.apply(to: scene)
        XCTAssertEqual(scene.nodes[nodeA.id]?.groupID, group.id)
        XCTAssertEqual(scene.nodes[nodeB.id]?.groupID, group.id)
        XCTAssertNotNil(scene.groups[group.id])

        command.inverse().apply(to: scene)
        XCTAssertNil(scene.nodes[nodeA.id]?.groupID)
        XCTAssertNil(scene.nodes[nodeB.id]?.groupID)
        XCTAssertNil(scene.groups[group.id])
    }

    func testUngroupRestoresPriorNestedGroupMembership() {
        let outerGroupID = GroupID()
        var node = makeNode()
        node.groupID = outerGroupID
        let scene = makeScene(with: [node])

        let innerGroup = DiagramGroup(memberNodeIDs: [node.id])
        let command = GroupNodesCommand(group: innerGroup, previousGroupIDs: [node.id: outerGroupID])
        command.apply(to: scene)
        XCTAssertEqual(scene.nodes[node.id]?.groupID, innerGroup.id)

        command.inverse().apply(to: scene)
        XCTAssertEqual(scene.nodes[node.id]?.groupID, outerGroupID)
    }

    func testCompositeCommandAppliesInOrderAndInvertsInReverse() {
        let nodeA = makeNode()
        let nodeB = makeNode(x: 500)
        let scene = makeScene(with: [nodeA])

        var movedA = nodeA
        movedA.position = Point2D(x: 999, y: 999)

        let composite = CompositeCommand([
            AddNodesCommand(nodes: [nodeB]),
            UpdateNodesCommand(before: [nodeA.id: nodeA], after: [nodeA.id: movedA])
        ])

        composite.apply(to: scene)
        XCTAssertNotNil(scene.nodes[nodeB.id])
        XCTAssertEqual(scene.nodes[nodeA.id]?.position.x, 999)

        composite.inverse().apply(to: scene)
        XCTAssertNil(scene.nodes[nodeB.id])
        XCTAssertEqual(scene.nodes[nodeA.id]?.position.x, 0)
    }

    func testCommandStackRegistersUndoAndRedoWithRealUndoManager() {
        let node = makeNode()
        let scene = makeScene(with: [node])
        let undoManager = UndoManager()
        let stack = CommandStack(scene: scene, undoManager: undoManager)

        var moved = node
        moved.position = Point2D(x: 500, y: 500)
        stack.perform(UpdateNodesCommand(before: [node.id: node], after: [node.id: moved]), actionName: "Move")

        XCTAssertEqual(scene.nodes[node.id]?.position.x, 500)
        XCTAssertTrue(undoManager.canUndo)

        undoManager.undo()
        XCTAssertEqual(scene.nodes[node.id]?.position.x, 0)
        XCTAssertTrue(undoManager.canRedo)

        undoManager.redo()
        XCTAssertEqual(scene.nodes[node.id]?.position.x, 500)
    }

    func testCommandStackMultiStepUndoRedoReturnsToExactInitialSnapshot() {
        let node = makeNode()
        let scene = makeScene(with: [node])
        let undoManager = UndoManager()
        let stack = CommandStack(scene: scene, undoManager: undoManager)

        func move(to point: Point2D) {
            guard let current = scene.nodes[node.id] else { return }
            var updated = current
            updated.position = point
            stack.perform(UpdateNodesCommand(before: [node.id: current], after: [node.id: updated]), actionName: "Move")
        }

        move(to: Point2D(x: 10, y: 10))
        move(to: Point2D(x: 20, y: 20))
        move(to: Point2D(x: 30, y: 30))

        undoManager.undo()
        undoManager.undo()
        undoManager.undo()

        XCTAssertEqual(scene.nodes[node.id], node, "three undos should return to the exact original snapshot")
    }
}
