import AppKit
import DiagramModel

/// The infinite diagram canvas: a real `NSView` drawing via Core Graphics,
/// never SwiftUI `Canvas` — per the Visual/UI Style requirements. Draws only
/// what the spatial index reports as intersecting the dirty rect; pan/zoom
/// changes are the one case that legitimately redraws the full view (the
/// transform itself changed, so there's no smaller dirty rect to compute).
///
/// Click-to-select and marquee selection live directly on this view rather
/// than behind a `DiagramInteraction` "tool" abstraction: there's only one
/// always-active behavior right now (select), so a tool-dispatch layer has
/// nothing to dispatch between yet. That abstraction earns its keep once
/// move/resize/draw-connector tools (step 8+) introduce real polymorphism.
///
/// TODO(Phase 1, later build-order steps): move/resize/rotate commands
/// driving per-gesture dirty rects instead of full reloads (step 8+), text
/// rendering via `CTFramesetter` (step 11), edges (step 13).
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

    /// Notifies the SwiftUI bridge when selection changes *from user
    /// interaction on this view* (click, marquee) — not called from
    /// `applyExternalSelection`, since that call already originated on the
    /// SwiftUI side and echoing it back would just be a no-op round trip.
    public var onSelectionChange: ((Set<NodeID>) -> Void)?

    private var nodes: [NodeID: DiagramNode] = [:]
    private let spatialIndex = SpatialGrid()

    public private(set) var selection: Set<NodeID> = []

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
        // Drop any selected IDs that no longer exist (e.g. reloading a
        // different page) rather than holding a stale, invisible selection.
        let prunedSelection = selection.intersection(nodes.keys)
        if prunedSelection != selection {
            updateSelectionFromInteraction(prunedSelection)
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

    // MARK: - Selection

    /// SwiftUI -> canvas direction (Inspector/search-driven selection, once
    /// those exist). Guarded against redundant work, but intentionally
    /// silent otherwise — see `onSelectionChange`'s doc comment for why this
    /// never echoes back out.
    public func applyExternalSelection(_ ids: Set<NodeID>) {
        guard selection != ids else { return }
        selection = ids
        needsDisplay = true
    }

    private func updateSelectionFromInteraction(_ ids: Set<NodeID>) {
        guard selection != ids else { return }
        selection = ids
        needsDisplay = true
        onSelectionChange?(selection)
    }

    /// Exact hit-test: `SpatialGrid` narrows to candidates near the point,
    /// then `ShapeGeometry`'s path (the same one `draw(_:in:)` uses, so
    /// hit-testing and drawing can never drift apart) decides which
    /// candidate — topmost by `zIndex` — was actually clicked.
    private func topmostNode(at contentPoint: CGPoint) -> NodeID? {
        let probe = CGRect(x: contentPoint.x - 1, y: contentPoint.y - 1, width: 2, height: 2)
        let candidates = spatialIndex.query(probe)
            .compactMap { nodes[$0] }
            .sorted { $0.zIndex > $1.zIndex }

        for node in candidates where !node.isHidden {
            let path = ShapeGeometry.path(for: node.type, in: node.frame)
            if path.contains(contentPoint) { return node.id }
        }
        return nil
    }

    // MARK: - Mouse / marquee

    private var marqueeStartView: CGPoint?
    private var marqueeCurrentView: CGPoint?

    private var marqueeViewRect: CGRect? {
        guard let start = marqueeStartView, let current = marqueeCurrentView else { return nil }
        return CGRect(
            x: min(start.x, current.x), y: min(start.y, current.y),
            width: abs(current.x - start.x), height: abs(current.y - start.y)
        )
    }

    public override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let viewPoint = convert(event.locationInWindow, from: nil)
        let contentPoint = viewport.viewToContent(point: viewPoint)
        let isExtending = event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.command)

        if let hitID = topmostNode(at: contentPoint) {
            if isExtending {
                var updated = selection
                if updated.contains(hitID) { updated.remove(hitID) } else { updated.insert(hitID) }
                updateSelectionFromInteraction(updated)
            } else if !selection.contains(hitID) {
                updateSelectionFromInteraction([hitID])
            }
            // TODO(step 8): begin a move-drag here when the hit node is
            // already selected, instead of only selecting it.
        } else {
            if !isExtending {
                updateSelectionFromInteraction([])
            }
            marqueeStartView = viewPoint
            marqueeCurrentView = viewPoint
        }
    }

    public override func mouseDragged(with event: NSEvent) {
        guard marqueeStartView != nil else { return }
        marqueeCurrentView = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    public override func mouseUp(with event: NSEvent) {
        defer {
            marqueeStartView = nil
            marqueeCurrentView = nil
            needsDisplay = true
        }
        guard let viewRect = marqueeViewRect, viewRect.width > 2 || viewRect.height > 2 else { return }

        let contentRect = viewport.viewToContent(rect: viewRect)
        let hits = spatialIndex.query(contentRect).filter { id in
            guard let node = nodes[id] else { return false }
            return contentRect.intersects(node.frame)
        }
        let isExtending = event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.command)
        updateSelectionFromInteraction(isExtending ? selection.union(hits) : Set(hits))
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

        // Selection handles and the marquee are drawn in view space (after
        // restoring the content transform) so their line width stays a
        // crisp, constant 1-2px regardless of zoom — matching how AppKit's
        // own selection chrome behaves.
        if !selection.isEmpty {
            drawSelectionHighlights(in: context)
        }
        if let marqueeRect = marqueeViewRect {
            drawMarquee(marqueeRect, in: context)
        }
    }

    private func drawSelectionHighlights(in context: CGContext) {
        context.saveGState()
        context.setStrokeColor(NSColor.controlAccentColor.cgColor)
        context.setLineWidth(2)
        var combinedContentBounds: CGRect?
        for id in selection {
            guard let node = nodes[id] else { continue }
            let viewRect = node.frame.applying(viewport.contentToViewTransform)
            context.stroke(viewRect.insetBy(dx: -3, dy: -3))
            combinedContentBounds = combinedContentBounds?.union(node.frame) ?? node.frame
        }
        context.restoreGState()

        // A dashed combined bounding box only reads as meaningful once
        // there's more than one object to bound together.
        guard selection.count > 1, let combined = combinedContentBounds else { return }
        let combinedViewRect = combined.applying(viewport.contentToViewTransform).insetBy(dx: -8, dy: -8)
        context.saveGState()
        context.setStrokeColor(NSColor.secondaryLabelColor.cgColor)
        context.setLineWidth(1)
        context.setLineDash(phase: 0, lengths: [4, 3])
        context.stroke(combinedViewRect)
        context.restoreGState()
    }

    /// Full-view invalidation during marquee drag (via `needsDisplay = true`
    /// in `mouseDragged`) is intentional, not a lapse in the dirty-rect
    /// discipline: the marquee itself sweeps across large, arbitrary regions
    /// each frame, so there's no small dirty rect to compute for "old
    /// marquee ∪ new marquee" — unlike node drag/resize (step 8+), which
    /// does get precise per-gesture dirty rects.
    private func drawMarquee(_ rect: CGRect, in context: CGContext) {
        context.saveGState()
        context.setFillColor(NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor)
        context.fill(rect)
        context.setStrokeColor(NSColor.controlAccentColor.cgColor)
        context.setLineWidth(1)
        context.stroke(rect)
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
