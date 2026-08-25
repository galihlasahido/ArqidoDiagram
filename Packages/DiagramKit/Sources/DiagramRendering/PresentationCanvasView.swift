import AppKit
import DiagramModel

/// Spec §PRESENTATION MODE: the read-only, full-screen "playback" surface —
/// deliberately a separate, much smaller `NSView` from `DiagramCanvasView`
/// rather than that view reused in a "read-only mode", so nothing in
/// mouse/keyboard editing (drag-to-move, marquee select, connector drawing,
/// text editing, ...) can ever fire while presenting. It shares
/// `PageRenderer`'s draw routine with the editor and PNG/SVG/PDF export, so
/// what's presented always matches what's on the canvas and in exported
/// output.
public final class PresentationCanvasView: NSView {
    public var page: DiagramPage? { didSet { needsDisplay = true } }
    public var viewport = CanvasViewport() { didSet { needsDisplay = true } }
    public var focusNodeIDs: Set<NodeID>? { didSet { needsDisplay = true } }

    public override var isFlipped: Bool { true }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    public override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        NSColor.black.setFill()
        dirtyRect.fill()

        guard let page else { return }
        context.saveGState()
        context.concatenate(viewport.contentToViewTransform)
        PageRenderer.draw(page, in: context, scale: viewport.scale, focusNodeIDs: focusNodeIDs)
        context.restoreGState()
    }
}
