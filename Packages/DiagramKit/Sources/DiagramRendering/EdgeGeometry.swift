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
        }
        return path
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
