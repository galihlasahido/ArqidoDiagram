import AppKit
import DiagramModel

/// The single, shared node/edge drawing logic used both by
/// `DiagramCanvasView`'s live on-screen `draw(_:)` and by `DiagramExport`'s
/// PNG/SVG/PDF adapters — this is what makes exported output match
/// on-screen rendering exactly, per the spec, rather than two independent
/// implementations drifting apart over time.
public enum PageRenderer {
    public static func contentBounds(of page: DiagramPage) -> CGRect {
        var result: CGRect?
        for node in page.nodes.values {
            result = result?.union(node.frame) ?? node.frame
        }
        return result ?? CGRect(x: 0, y: 0, width: 800, height: 600)
    }

    /// Draws every edge then every node (edges behind nodes — see
    /// `DiagramCanvasView`'s doc comment on why) into `context`, which must
    /// already have any content-space transform concatenated. `scale` is
    /// used only to keep stroke widths a constant *content-space-relative*
    /// thickness (matching the live canvas's `1 / viewport.scale`
    /// compensation) — pass `1` for export, where output pixels already
    /// map 1:1 to content-space points at whatever DPI the caller chose.
    public static func draw(_ page: DiagramPage, in context: CGContext, scale: CGFloat = 1, editingNodeID: NodeID? = nil) {
        for edge in page.edges.values.sorted(by: { $0.zIndex < $1.zIndex }) {
            drawEdge(edge, nodes: page.nodes, in: context, scale: scale)
        }
        for node in page.nodes.values.sorted(by: { $0.zIndex < $1.zIndex }) {
            drawNode(node, in: context, scale: scale, skipText: node.id == editingNodeID)
        }
    }

    public static func drawNode(_ node: DiagramNode, in context: CGContext, scale: CGFloat = 1, skipText: Bool = false) {
        guard !node.isHidden else { return }
        let path = ShapeGeometry.path(for: node.type, in: node.frame)

        // Unstyled nodes (the common case — most shapes are never touched
        // in the Inspector's Appearance section) default to a light,
        // neutral fill with the user's own macOS accent color as the
        // border, not a hardcoded saturated block — the same "outlined
        // card" language Apple's own apps use, and it reads as native
        // regardless of which of the twelve system accent colors the user
        // has chosen in System Settings. Re-resolved on every draw (never
        // baked into `node.style`), so it still tracks light/dark and a
        // changed accent color live.
        let fillColor = node.style.fill.map(NSColor.init) ?? .controlBackgroundColor
        let strokeColor = node.style.strokeColor.map(NSColor.init) ?? .controlAccentColor

        context.saveGState()
        if node.rotation != 0 {
            let center = node.frame.center
            context.translateBy(x: center.x, y: center.y)
            context.rotate(by: CGFloat(node.rotation))
            context.translateBy(x: -center.x, y: -center.y)
        }
        context.setAlpha(node.style.opacity)
        context.addPath(path)
        context.setFillColor(fillColor.cgColor)
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(max(node.style.strokeWidth, 0.5) / scale)
        context.drawPath(using: node.style.strokeWidth > 0 ? .fillStroke : .fill)

        if let iconType = node.iconType {
            drawIcon(iconType, in: node.frame, context: context, scale: scale)
        }

        if !skipText {
            drawText(node, in: context)
        }
        context.restoreGState()
    }

    /// Icon badges are a fixed content-space size (not proportional to the
    /// node), matching how a real vendor-icon badge stays legible/consistent
    /// regardless of how large the surrounding shape is resized.
    private static func drawIcon(_ iconType: TechIconType, in frame: CGRect, context: CGContext, scale: CGFloat) {
        let badgeSize: CGFloat = min(28, min(frame.width, frame.height) * 0.5)
        guard badgeSize > 4 else { return }
        let inset: CGFloat = 6
        let badgeRect = CGRect(
            x: frame.minX + inset,
            y: frame.minY + inset,
            width: badgeSize,
            height: badgeSize
        )
        let path = IconGeometry.path(for: iconType, in: badgeRect)
        context.saveGState()
        context.setStrokeColor(NSColor.labelColor.cgColor)
        context.setLineWidth(1.25 / scale)
        context.addPath(path)
        context.strokePath()
        context.restoreGState()
    }

    private static func drawText(_ node: DiagramNode, in context: CGContext) {
        guard let text = node.text, !text.string.isEmpty else { return }

        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        defer { NSGraphicsContext.current = previous }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributed = NSAttributedString(string: text.string, attributes: [
            .font: NSFont.systemFont(ofSize: CGFloat(node.style.font?.size ?? 13)),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ])

        let insetRect = node.frame.insetBy(dx: 6, dy: 6)
        let fitted = attributed.boundingRect(with: insetRect.size, options: [.usesLineFragmentOrigin])
        let drawRect = CGRect(x: insetRect.minX, y: insetRect.midY - fitted.height / 2, width: insetRect.width, height: fitted.height)
        attributed.draw(with: drawRect, options: [.usesLineFragmentOrigin])
    }

    public static func drawEdge(_ edge: DiagramEdge, nodes: [NodeID: DiagramNode], in context: CGContext, scale: CGFloat = 1) {
        guard !edge.isHidden else { return }
        let targetAim = aimPoint(for: edge.target, nodes: nodes)
        let sourceAim = aimPoint(for: edge.source, nodes: nodes)
        guard let source = EdgeGeometry.resolvedPoint(for: edge.source, nodes: nodes, towards: targetAim),
              let target = EdgeGeometry.resolvedPoint(for: edge.target, nodes: nodes, towards: sourceAim) else { return }

        let path = EdgeGeometry.path(from: source, to: target, routing: edge.routing)
        context.saveGState()
        context.setStrokeColor(NSColor(edge.style.strokeColor ?? .system(.systemGray)).cgColor)
        context.setLineWidth(max(edge.style.strokeWidth, 0.5) / scale)
        if edge.style.dash == .dashed {
            context.setLineDash(phase: 0, lengths: [6 / scale, 4 / scale])
        } else if edge.style.dash == .dotted {
            context.setLineDash(phase: 0, lengths: [1.5 / scale, 3 / scale])
        }
        context.addPath(path)
        context.strokePath()

        let arrowColor = NSColor(edge.style.strokeColor ?? .system(.systemGray)).cgColor
        if let startArrow = EdgeGeometry.arrowheadPath(from: target, tip: source, style: edge.style.startArrow, size: 9 / scale) {
            context.setFillColor(arrowColor)
            context.addPath(startArrow)
            context.drawPath(using: filled(edge.style.startArrow) ? .fillStroke : .stroke)
        }
        if let endArrow = EdgeGeometry.arrowheadPath(from: source, tip: target, style: edge.style.endArrow, size: 9 / scale) {
            context.setFillColor(arrowColor)
            context.addPath(endArrow)
            context.drawPath(using: filled(edge.style.endArrow) ? .fillStroke : .stroke)
        }
        context.restoreGState()
    }

    private static func filled(_ style: ArrowheadStyle) -> Bool {
        style == .filled || style == .diamond || style == .circle
    }

    private static func aimPoint(for endpoint: EndpointRef, nodes: [NodeID: DiagramNode]) -> CGPoint {
        switch endpoint {
        case .point(let p): return CGPoint(x: p.x, y: p.y)
        case .node(let id, _): return nodes[id]?.frame.center ?? .zero
        }
    }
}
