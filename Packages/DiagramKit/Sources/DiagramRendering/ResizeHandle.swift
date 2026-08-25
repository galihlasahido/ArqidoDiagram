import CoreGraphics

/// The 8 resize handles around a selection's bounding box. Pure geometry —
/// no `NSView` dependency — so it's unit-testable in plain XCTest.
public enum ResizeHandle: CaseIterable, Sendable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left

    public func point(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft: return CGPoint(x: rect.minX, y: rect.minY)
        case .top: return CGPoint(x: rect.midX, y: rect.minY)
        case .topRight: return CGPoint(x: rect.maxX, y: rect.minY)
        case .right: return CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        case .bottom: return CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomLeft: return CGPoint(x: rect.minX, y: rect.maxY)
        case .left: return CGPoint(x: rect.minX, y: rect.midY)
        }
    }

    private static let minSize: CGFloat = 8

    /// The new bounding box when this handle is dragged to `point` in
    /// content space, keeping the opposite edge/corner of `startBounds`
    /// fixed. Clamped to a minimum size rather than allowing the box to
    /// invert past the fixed edge.
    public func resized(from startBounds: CGRect, draggedTo point: CGPoint) -> CGRect {
        var minX = startBounds.minX
        var maxX = startBounds.maxX
        var minY = startBounds.minY
        var maxY = startBounds.maxY

        switch self {
        case .topLeft, .left, .bottomLeft: minX = point.x
        case .topRight, .right, .bottomRight: maxX = point.x
        case .top, .bottom: break
        }
        switch self {
        case .topLeft, .top, .topRight: minY = point.y
        case .bottomLeft, .bottom, .bottomRight: maxY = point.y
        case .left, .right: break
        }

        if maxX - minX < Self.minSize {
            switch self {
            case .topLeft, .left, .bottomLeft: minX = maxX - Self.minSize
            case .topRight, .right, .bottomRight: maxX = minX + Self.minSize
            case .top, .bottom: break
            }
        }
        if maxY - minY < Self.minSize {
            switch self {
            case .topLeft, .top, .topRight: minY = maxY - Self.minSize
            case .bottomLeft, .bottom, .bottomRight: maxY = minY + Self.minSize
            case .left, .right: break
            }
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

extension CGRect {
    public var center: CGPoint { CGPoint(x: midX, y: midY) }
}

/// Rotates `point` around `center` by `angle` radians (positive =
/// counter-clockwise in a standard, non-flipped math sense — callers in a
/// flipped `NSView` should negate as needed).
public func rotatePoint(_ point: CGPoint, around center: CGPoint, by angle: CGFloat) -> CGPoint {
    let dx = point.x - center.x
    let dy = point.y - center.y
    let cosA = cos(angle)
    let sinA = sin(angle)
    return CGPoint(x: center.x + dx * cosA - dy * sinA, y: center.y + dx * sinA + dy * cosA)
}
