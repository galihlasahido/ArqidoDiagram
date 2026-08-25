import CoreGraphics
import DiagramModel

/// Resolves edge endpoints/routing/arrowheads to concrete geometry. Edge
/// endpoints are computed live from the current node positions every draw
/// — never cached as absolute points — which is what makes edges
/// automatically re-route when a connected node moves, with no extra code
/// needed on the move path.
public enum EdgeGeometry {
    /// Where an edge endpoint actually sits: a dangling point endpoint
    /// resolves directly; a node endpoint resolves to the point where the
    /// straight line from the node's center towards `other` exits the
    /// node's bounding box (ports aren't populated yet — Phase 2+).
    public static func resolvedPoint(for endpoint: EndpointRef, nodes: [NodeID: DiagramNode], towards other: CGPoint) -> CGPoint? {
        switch endpoint {
        case .point(let p):
            return CGPoint(x: p.x, y: p.y)
        case .node(let id, _):
            guard let node = nodes[id] else { return nil }
            return clippedPoint(from: node.frame.center, towards: other, in: node.frame)
        }
    }

    /// The point where the ray from `from` (assumed at or inside `rect`)
    /// towards `to` exits `rect`.
    static func clippedPoint(from: CGPoint, towards to: CGPoint, in rect: CGRect) -> CGPoint {
        let dx = to.x - from.x
        let dy = to.y - from.y
        guard dx != 0 || dy != 0 else { return from }

        let halfW = rect.width / 2
        let halfH = rect.height / 2
        let scaleX = dx != 0 ? halfW / abs(dx) : .greatestFiniteMagnitude
        let scaleY = dy != 0 ? halfH / abs(dy) : .greatestFiniteMagnitude
        let scale = min(scaleX, scaleY)
        return CGPoint(x: from.x + dx * scale, y: from.y + dy * scale)
    }

    public static func path(from source: CGPoint, to target: CGPoint, routing: RoutingStyle) -> CGPath {
        let path = CGMutablePath()
        path.move(to: source)
        switch routing {
        case .straight:
            path.addLine(to: target)
        case .orthogonal:
            let mid = CGPoint(x: target.x, y: source.y)
            path.addLine(to: mid)
            path.addLine(to: target)
        case .curved:
            let c1 = CGPoint(x: (source.x + target.x) / 2, y: source.y)
            let c2 = CGPoint(x: (source.x + target.x) / 2, y: target.y)
            path.addCurve(to: target, control1: c1, control2: c2)
        case .isometric:
            // Two segments, each exactly along one of the isometric grid's
            // two axes — A = (2,1), B = (2,-1) (the common 2:1-pixel-ratio
            // convention). Solving `target - source = alpha*A + beta*B` for
            // alpha (a 2x2 linear system, determinant -4) gives the one
            // bend point that keeps both segments on-axis while still
            // landing exactly on `target`, for any pair of points.
            let dx = target.x - source.x
            let dy = target.y - source.y
            let alpha = (dx + 2 * dy) / 4
            let bend = CGPoint(x: source.x + alpha * 2, y: source.y + alpha * 1)
            path.addLine(to: bend)
            path.addLine(to: target)
        case .entityRelation:
            let midX = (source.x + target.x) / 2
            path.addLine(to: CGPoint(x: midX, y: source.y))
            path.addLine(to: CGPoint(x: midX, y: target.y))
            path.addLine(to: target)
        }
        return path
    }

    /// Resolves both endpoints of `edge` against `nodes` in one call — the
    /// shared implementation `PageRenderer.drawEdge` and
    /// `DiagramCanvasView`'s edge hit-testing/selection-highlight both use,
    /// so "what's on screen" and "what gets picked/highlighted" can never
    /// drift apart.
    public static func resolvedEndpoints(for edge: DiagramEdge, nodes: [NodeID: DiagramNode]) -> (source: CGPoint, target: CGPoint)? {
        let targetAim = aimPoint(for: edge.target, nodes: nodes)
        let sourceAim = aimPoint(for: edge.source, nodes: nodes)
        guard let source = resolvedPoint(for: edge.source, nodes: nodes, towards: targetAim),
              let target = resolvedPoint(for: edge.target, nodes: nodes, towards: sourceAim) else { return nil }
        return (source, target)
    }

    static func aimPoint(for endpoint: EndpointRef, nodes: [NodeID: DiagramNode]) -> CGPoint {
        switch endpoint {
        case .point(let p): return CGPoint(x: p.x, y: p.y)
        case .node(let id, _): return nodes[id]?.frame.center ?? .zero
        }
    }

    /// A small arrowhead at `tip`, pointing away from `from` — `nil` for
    /// `.none`. `.open` is a two-stroke chevron; `.filled`/`.diamond` close
    /// into a fillable shape; `.circle` is a small dot.
    public static func arrowheadPath(from: CGPoint, tip: CGPoint, style: ArrowheadStyle, size: CGFloat = 9) -> CGPath? {
        guard style != .none else { return nil }
        let angle = atan2(tip.y - from.y, tip.x - from.x)
        let path = CGMutablePath()

        switch style {
        case .none:
            return nil
        case .open, .filled:
            let back1 = CGPoint(x: tip.x - size * cos(angle - .pi / 6), y: tip.y - size * sin(angle - .pi / 6))
            let back2 = CGPoint(x: tip.x - size * cos(angle + .pi / 6), y: tip.y - size * sin(angle + .pi / 6))
            path.move(to: back1)
            path.addLine(to: tip)
            path.addLine(to: back2)
            if style == .filled { path.closeSubpath() }
        case .diamond:
            let back = CGPoint(x: tip.x - size * cos(angle), y: tip.y - size * sin(angle))
            let mid = CGPoint(x: (tip.x + back.x) / 2, y: (tip.y + back.y) / 2)
            let side1 = CGPoint(x: mid.x - size / 2 * sin(angle), y: mid.y + size / 2 * cos(angle))
            let side2 = CGPoint(x: mid.x + size / 2 * sin(angle), y: mid.y - size / 2 * cos(angle))
            path.move(to: tip)
            path.addLine(to: side1)
            path.addLine(to: back)
            path.addLine(to: side2)
            path.closeSubpath()
        case .circle:
            let center = CGPoint(x: tip.x - size / 2 * cos(angle), y: tip.y - size / 2 * sin(angle))
            path.addEllipse(in: CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size))
        }
        return path
    }
}
