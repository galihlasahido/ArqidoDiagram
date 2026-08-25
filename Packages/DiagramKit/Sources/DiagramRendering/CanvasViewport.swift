import CoreGraphics

/// Owns the single pan/zoom transform for `DiagramCanvasView`. Content-space
/// -> view-space conversion happens via `contentToViewTransform` (used in
/// `draw(_:)`); view-space -> content-space happens via `viewToContent`
/// (used for hit-testing and mouse events). Kept as a plain value type with
/// no `NSView` dependency so it's usable from plain XCTest.
public struct CanvasViewport: Equatable {
    public var scale: CGFloat
    /// The content-space point currently at the view's origin (top-left,
    /// since `DiagramCanvasView.isFlipped == true`).
    public var contentOrigin: CGPoint

    public static let minScale: CGFloat = 0.05
    public static let maxScale: CGFloat = 8

    public init(scale: CGFloat = 1, contentOrigin: CGPoint = .zero) {
        self.scale = scale
        self.contentOrigin = contentOrigin
    }

    public var contentToViewTransform: CGAffineTransform {
        CGAffineTransform(
            a: scale, b: 0, c: 0, d: scale,
            tx: -contentOrigin.x * scale,
            ty: -contentOrigin.y * scale
        )
    }

    public func viewToContent(point: CGPoint) -> CGPoint {
        CGPoint(x: point.x / scale + contentOrigin.x, y: point.y / scale + contentOrigin.y)
    }

    public func viewToContent(rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX / scale + contentOrigin.x,
            y: rect.minY / scale + contentOrigin.y,
            width: rect.width / scale,
            height: rect.height / scale
        )
    }

    /// A viewport that frames `contentBounds` centered within `viewSize`,
    /// with `padding` view-space points of breathing room on every side.
    public static func fitting(contentBounds: CGRect, viewSize: CGSize, padding: CGFloat = 40) -> CanvasViewport {
        guard contentBounds.width > 0, contentBounds.height > 0, viewSize.width > 0, viewSize.height > 0 else {
            return CanvasViewport()
        }
        let availableWidth = max(viewSize.width - padding * 2, 1)
        let availableHeight = max(viewSize.height - padding * 2, 1)
        let scale = min(
            min(availableWidth / contentBounds.width, availableHeight / contentBounds.height),
            maxScale
        ).clamped(to: minScale...maxScale)

        let origin = CGPoint(
            x: contentBounds.midX - (viewSize.width / 2) / scale,
            y: contentBounds.midY - (viewSize.height / 2) / scale
        )
        return CanvasViewport(scale: scale, contentOrigin: origin)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
