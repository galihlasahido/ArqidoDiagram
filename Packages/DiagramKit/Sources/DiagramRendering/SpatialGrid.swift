import CoreGraphics
import DiagramModel

/// Uniform-grid spatial index for hit-testing and dirty-rect queries.
/// Chosen over an R-tree: diagram nodes are mostly modest, roughly-uniform
/// rectangles with normal spacing, not deeply overlapping arbitrary
/// geometry — a grid is far simpler to keep correct under constant mutation
/// (every drag frame) for that shape of data. No `NSView` dependency, so
/// it's unit-testable in plain XCTest.
public final class SpatialGrid {
    private struct Cell: Hashable {
        var x: Int
        var y: Int
    }

    private let cellSize: CGFloat
    private var buckets: [Cell: Set<NodeID>] = [:]
    private var boundsByID: [NodeID: CGRect] = [:]

    public init(cellSize: CGFloat = 256) {
        self.cellSize = cellSize
    }

    public var isEmpty: Bool { boundsByID.isEmpty }

    public func insert(_ id: NodeID, bounds: CGRect) {
        boundsByID[id] = bounds
        for cell in cells(overlapping: bounds) {
            buckets[cell, default: []].insert(id)
        }
    }

    @discardableResult
    public func remove(_ id: NodeID) -> Bool {
        guard let bounds = boundsByID.removeValue(forKey: id) else { return false }
        for cell in cells(overlapping: bounds) {
            buckets[cell]?.remove(id)
            if buckets[cell]?.isEmpty == true { buckets.removeValue(forKey: cell) }
        }
        return true
    }

    public func update(_ id: NodeID, bounds: CGRect) {
        remove(id)
        insert(id, bounds: bounds)
    }

    public func removeAll() {
        buckets.removeAll()
        boundsByID.removeAll()
    }

    public func bounds(for id: NodeID) -> CGRect? {
        boundsByID[id]
    }

    /// IDs whose bounding box intersects `rect`. Callers still need an
    /// exact-geometry test (`ShapeGeometry`) for pixel-accurate hit-testing
    /// — this only narrows the candidate set.
    public func query(_ rect: CGRect) -> Set<NodeID> {
        var result: Set<NodeID> = []
        for cell in cells(overlapping: rect) {
            if let ids = buckets[cell] { result.formUnion(ids) }
        }
        return result
    }

    private func cells(overlapping rect: CGRect) -> [Cell] {
        guard cellSize > 0, rect.width.isFinite, rect.height.isFinite,
              rect.minX.isFinite, rect.minY.isFinite else { return [] }

        let minX = Int(floor(rect.minX / cellSize))
        let maxX = Int(floor(rect.maxX / cellSize))
        let minY = Int(floor(rect.minY / cellSize))
        let maxY = Int(floor(rect.maxY / cellSize))

        var result: [Cell] = []
        result.reserveCapacity((maxX - minX + 1) * (maxY - minY + 1))
        for x in minX...maxX {
            for y in minY...maxY {
                result.append(Cell(x: x, y: y))
            }
        }
        return result
    }
}
