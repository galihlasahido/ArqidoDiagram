import XCTest
import DiagramModel
@testable import DiagramCommands

final class AnyObjectIDTests: XCTestCase {
    func testDistinctIDKindsAreNotEqualEvenWithSameUUID() {
        let uuid = UUID()
        let nodeID = AnyObjectID.node(NodeID(uuid))
        let edgeID = AnyObjectID.edge(EdgeID(uuid))
        XCTAssertNotEqual(nodeID, edgeID)
    }

    func testSameIDsAreEqualAndHashConsistently() {
        let id = NodeID()
        XCTAssertEqual(AnyObjectID.node(id), AnyObjectID.node(id))
        XCTAssertEqual(Set([AnyObjectID.node(id), AnyObjectID.node(id)]).count, 1)
    }
}

// TODO(Phase 1, build-order step 8): concrete Command implementations
// (MoveObjectsCommand, ResizeObjectCommand, ...) and CommandStack tests
// (apply -> undo -> reassert scene equality) land here.
