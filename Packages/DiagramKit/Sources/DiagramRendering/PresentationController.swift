import CoreGraphics
import DiagramModel

extension Rect2D {
    public var cgRect: CGRect {
        CGRect(x: origin.x, y: origin.y, width: size.width, height: size.height)
    }

    public init(_ rect: CGRect) {
        self.init(origin: Point2D(x: rect.origin.x, y: rect.origin.y), size: Size2D(width: rect.width, height: rect.height))
    }
}

/// Spec §PRESENTATION MODE: "Frames, Full screen, Previous, Next, Zoom,
/// Focus". Pure navigation/zoom/focus state — no `NSWindow`/`NSView`
/// dependency, so it's testable in plain XCTest; `PresentationWindowController`
/// (app target) is the thin AppKit binding that actually puts a window on
/// screen and reads/writes this.
public struct PresentationController: Equatable {
    public private(set) var frames: [PresentationFrame]
    public private(set) var currentIndex: Int
    /// Multiplied onto the frame's own fitted scale — reset to 1 whenever
    /// the current frame changes, so "Zoom" is always relative to the new
    /// slide, not carried over from the last one.
    public private(set) var zoomMultiplier: CGFloat
    public private(set) var isFocusModeOn: Bool

    public static let minZoomMultiplier: CGFloat = 0.25
    public static let maxZoomMultiplier: CGFloat = 4

    public init(frames: [PresentationFrame], startIndex: Int = 0) {
        self.frames = frames
        self.currentIndex = frames.indices.contains(startIndex) ? startIndex : 0
        self.zoomMultiplier = 1
        self.isFocusModeOn = false
    }

    public var currentFrame: PresentationFrame? {
        frames.indices.contains(currentIndex) ? frames[currentIndex] : nil
    }

    public var hasNext: Bool { currentIndex < frames.count - 1 }
    public var hasPrevious: Bool { currentIndex > 0 }

    public mutating func next() {
        guard hasNext else { return }
        currentIndex += 1
        zoomMultiplier = 1
    }

    public mutating func previous() {
        guard hasPrevious else { return }
        currentIndex -= 1
        zoomMultiplier = 1
    }

    public mutating func jump(to index: Int) {
        guard frames.indices.contains(index) else { return }
        currentIndex = index
        zoomMultiplier = 1
    }

    public mutating func zoomIn(step: CGFloat = 1.25) {
        zoomMultiplier = min(zoomMultiplier * step, Self.maxZoomMultiplier)
    }

    public mutating func zoomOut(step: CGFloat = 1.25) {
        zoomMultiplier = max(zoomMultiplier / step, Self.minZoomMultiplier)
    }

    public mutating func resetZoom() {
        zoomMultiplier = 1
    }

    public mutating func toggleFocus() {
        isFocusModeOn.toggle()
    }

    /// The viewport to render the current frame at, given the presentation
    /// window's current view size — fits `currentFrame.rect` (via the same
    /// `CanvasViewport.fitting` the editor's own "Fit to Screen" uses), then
    /// applies `zoomMultiplier` on top.
    public func viewport(for viewSize: CGSize) -> CanvasViewport? {
        guard let currentFrame else { return nil }
        var viewport = CanvasViewport.fitting(contentBounds: currentFrame.rect.cgRect, viewSize: viewSize, padding: 0)
        let center = CGPoint(
            x: viewport.contentOrigin.x + (viewSize.width / 2) / viewport.scale,
            y: viewport.contentOrigin.y + (viewSize.height / 2) / viewport.scale
        )
        viewport.scale = (viewport.scale * zoomMultiplier).clamped(to: CanvasViewport.minScale...CanvasViewport.maxScale)
        viewport.contentOrigin = CGPoint(
            x: center.x - (viewSize.width / 2) / viewport.scale,
            y: center.y - (viewSize.height / 2) / viewport.scale
        )
        return viewport
    }

    /// `nil` when Focus is off (spec: dim nothing); the current frame's
    /// `focusNodeIDs` set when it's on.
    public var activeFocusNodeIDs: Set<NodeID>? {
        guard isFocusModeOn, let currentFrame, !currentFrame.focusNodeIDs.isEmpty else { return nil }
        return Set(currentFrame.focusNodeIDs)
    }
}
