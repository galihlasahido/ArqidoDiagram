import AppKit
import DiagramModel

/// The infinite diagram canvas: a real `NSView` drawing via Core Graphics,
/// never SwiftUI `Canvas` — per the Visual/UI Style requirements. Draws only
/// what the spatial index reports as intersecting the dirty rect; pan/zoom
/// changes are the one case that legitimately redraws the full view (the
/// transform itself changed, so there's no smaller dirty rect to compute).
///
/// TODO(Phase 1, later build-order steps): selection/marquee (step 7),
/// move/resize/rotate commands driving per-gesture dirty rects instead of
/// full reloads (step 8+), text rendering via `CTFramesetter` (step 11),
/// edges (step 13).
public final class DiagramCanvasView: NSView {
    public var viewport = CanvasViewport() {
        didSet {
            guard viewport != oldValue else { return }
            needsDisplay = true
            onViewportChange?(viewport)
        }
    }

    /// Notifies the SwiftUI bridge of viewport changes (zoom%, for the
    /// status bar) without making this view depend on SwiftUI/Combine.
    public var onViewportChange: ((CanvasViewport) -> Void)?

    private var nodes: [NodeID: DiagramNode] = [:]
    private let spatialIndex = SpatialGrid()

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    /// Top-left origin, y increasing downward — the standard 2D
    /// diagram-editor convention `DiagramModel.Point2D` assumes.
    public override var isFlipped: Bool { true }

    public override var acceptsFirstResponder: Bool { true }

    // MARK: - Content

    private var hasPerformedInitialFit = false

    /// Fits on the first resize where `bounds` has actually settled to a
    /// plausible real size — calling `fitToScreen()` right after
    /// `makeNSView`, or on an early/intermediate placeholder frame before
    /// `NavigationSplitView`'s column negotiation settles, would compute a
    /// scale from a transient, too-small frame. 120pt is comfortably above
    /// any such placeholder frame but below any real canvas pane size.
    ///
    /// `setFrameSize(_:)`, not `layout()`, is the hook: SwiftUI's
    /// `NSViewRepresentable` bridge resizes this view directly (it doesn't
    /// necessarily drive AppKit's own Auto Layout `layout()` pass), so
    /// `setFrameSize` is the one override guaranteed to fire whenever this
    /// view's actual size changes, regardless of hosting mechanism.
    private static let minimumPlausibleDimension: CGFloat = 120

    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        performInitialFitIfNeeded()
    }

    private func performInitialFitIfNeeded() {
        guard !hasPerformedInitialFit,
              bounds.width > Self.minimumPlausibleDimension,
              bounds.height > Self.minimumPlausibleDimension else { return }
        hasPerformedInitialFit = true
        fitToScreen()
    }

    public func loadNodes(_ newNodes: [DiagramNode]) {
        nodes = Dictionary(uniqueKeysWithValues: newNodes.map { ($0.id, $0) })
        spatialIndex.removeAll()
        for node in newNodes {
            spatialIndex.insert(node.id, bounds: node.frame)
        }
        needsDisplay = true
    }

    public var nodeCount: Int { nodes.count }

    public func fitToScreen(padding: CGFloat = 40) {
        viewport = CanvasViewport.fitting(contentBounds: contentBounds(), viewSize: bounds.size, padding: padding)
    }

    private func contentBounds() -> CGRect {
        var result: CGRect?
        for node in nodes.values {
            result = result?.union(node.frame) ?? node.frame
        }
        return result ?? CGRect(x: 0, y: 0, width: 800, height: 600)
    }

    // MARK: - Drawing

    public override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.setFillColor(NSColor.textBackgroundColor.cgColor)
        context.fill(dirtyRect)

        context.saveGState()
        context.concatenate(viewport.contentToViewTransform)

        let contentDirtyRect = viewport.viewToContent(rect: dirtyRect)
        let candidateIDs = spatialIndex.query(contentDirtyRect)
        let visibleNodes = candidateIDs.compactMap { nodes[$0] }.sorted { $0.zIndex < $1.zIndex }
        for node in visibleNodes {
            draw(node, in: context)
        }

        context.restoreGState()
    }

    private func draw(_ node: DiagramNode, in context: CGContext) {
        guard !node.isHidden else { return }
        let path = ShapeGeometry.path(for: node.type, in: node.frame)

        let fillColor = NSColor(node.style.fill ?? .system(.systemBlue))
        let strokeColor = NSColor(node.style.strokeColor ?? .system(.systemGray))

        context.saveGState()
        context.setAlpha(node.style.opacity)
        context.addPath(path)
        context.setFillColor(fillColor.cgColor)
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(max(node.style.strokeWidth, 0.5) / viewport.scale)
        context.drawPath(using: node.style.strokeWidth > 0 ? .fillStroke : .fill)
        context.restoreGState()

        // TODO(step 11): draw node.text via CTFramesetter/NSAttributedString.
    }

    // MARK: - Pan / zoom

    public override func scrollWheel(with event: NSEvent) {
        let contentDelta = CGVector(dx: -event.scrollingDeltaX / viewport.scale, dy: -event.scrollingDeltaY / viewport.scale)
        viewport.contentOrigin.x += contentDelta.dx
        viewport.contentOrigin.y += contentDelta.dy
    }

    public override func magnify(with event: NSEvent) {
        let viewPoint = convert(event.locationInWindow, from: nil)
        let contentPointBefore = viewport.viewToContent(point: viewPoint)

        viewport.scale = (viewport.scale * (1 + event.magnification))
            .clamped(to: CanvasViewport.minScale...CanvasViewport.maxScale)

        let contentPointAfter = viewport.viewToContent(point: viewPoint)
        viewport.contentOrigin.x += contentPointBefore.x - contentPointAfter.x
        viewport.contentOrigin.y += contentPointBefore.y - contentPointAfter.y
    }
}

extension DiagramNode {
    var frame: CGRect {
        CGRect(x: position.x, y: position.y, width: size.width, height: size.height)
    }
}
