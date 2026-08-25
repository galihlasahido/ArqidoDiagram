import XCTest
import DiagramModel
@testable import DiagramRendering

final class SpatialGridTests: XCTestCase {
    func testQueryFindsOverlappingNode() {
        let grid = SpatialGrid(cellSize: 100)
        let id = NodeID()
        grid.insert(id, bounds: CGRect(x: 50, y: 50, width: 40, height: 40))

        XCTAssertEqual(grid.query(CGRect(x: 0, y: 0, width: 200, height: 200)), [id])
        XCTAssertEqual(grid.query(CGRect(x: 1000, y: 1000, width: 10, height: 10)), [])
    }

    func testNodeSpanningMultipleCellsIsFoundFromEitherCell() {
        let grid = SpatialGrid(cellSize: 100)
        let id = NodeID()
        // Straddles the x=100 cell boundary.
        grid.insert(id, bounds: CGRect(x: 80, y: 10, width: 40, height: 20))

        XCTAssertTrue(grid.query(CGRect(x: 0, y: 0, width: 100, height: 100)).contains(id))
        XCTAssertTrue(grid.query(CGRect(x: 100, y: 0, width: 100, height: 100)).contains(id))
    }

    func testUpdateMovesNodeOutOfItsOldCell() {
        let grid = SpatialGrid(cellSize: 100)
        let id = NodeID()
        grid.insert(id, bounds: CGRect(x: 10, y: 10, width: 20, height: 20))
        grid.update(id, bounds: CGRect(x: 1000, y: 1000, width: 20, height: 20))

        XCTAssertFalse(grid.query(CGRect(x: 0, y: 0, width: 100, height: 100)).contains(id))
        XCTAssertTrue(grid.query(CGRect(x: 990, y: 990, width: 50, height: 50)).contains(id))
    }

    func testRemoveDropsNodeFromEveryCellItOccupied() {
        let grid = SpatialGrid(cellSize: 100)
        let id = NodeID()
        grid.insert(id, bounds: CGRect(x: 80, y: 80, width: 300, height: 300))
        XCTAssertTrue(grid.remove(id))
        XCTAssertTrue(grid.query(CGRect(x: -1000, y: -1000, width: 4000, height: 4000)).isEmpty)
    }

    func testQueryScalesToFiveThousandNodesWithinBudget() {
        let grid = SpatialGrid()
        var ids: [NodeID] = []
        ids.reserveCapacity(5000)
        for i in 0..<5000 {
            let id = NodeID()
            ids.append(id)
            let x = CGFloat((i % 100) * 300)
            let y = CGFloat((i / 100) * 300)
            grid.insert(id, bounds: CGRect(x: x, y: y, width: 200, height: 120))
        }

        measure {
            _ = grid.query(CGRect(x: 5000, y: 5000, width: 1200, height: 800))
        }
    }
}
