import CoreGraphics
import Foundation
import DiagramModel
import DiagramRendering

/// Hand-serializes SVG rather than going through Core Graphics (there's no
/// public CGContext SVG backend on macOS) — walks each node/edge's
/// `CGPath` (the exact same paths `ShapeGeometry`/`EdgeGeometry` produce for
/// on-screen drawing) into SVG path data, so shapes match the canvas
/// exactly even though the serialization itself is bespoke.
public enum SVGExportAdapter {
    public static func string(for page: DiagramPage, padding: CGFloat = 40) -> String {
        let bounds = PageRenderer.contentBounds(of: page).insetBy(dx: -padding, dy: -padding)

        var svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="\(fmt(bounds.minX)) \(fmt(bounds.minY)) \(fmt(bounds.width)) \(fmt(bounds.height))" width="\(Int(bounds.width))" height="\(Int(bounds.height))">
        <rect x="\(fmt(bounds.minX))" y="\(fmt(bounds.minY))" width="\(fmt(bounds.width))" height="\(fmt(bounds.height))" fill="white"/>

        """

        for edge in page.edges.values.sorted(by: { $0.zIndex < $1.zIndex }) {
            svg += svgForEdge(edge, nodes: page.nodes)
        }
        for node in page.nodes.values.sorted(by: { $0.zIndex < $1.zIndex }) where !node.isHidden {
            svg += svgForNode(node)
        }

        svg += "</svg>\n"
        return svg
    }

    public static func write(_ page: DiagramPage, to url: URL, padding: CGFloat = 40) async throws {
        let content = string(for: page, padding: padding)
        try await Task.detached(priority: .userInitiated) {
            try content.write(to: url, atomically: true, encoding: .utf8)
        }.value
    }

    private static func svgForNode(_ node: DiagramNode) -> String {
        let path = ShapeGeometry.path(for: node.type, in: node.frame)
        let fill = svgColor(node.style.fill ?? .system(.systemBlue))
        let stroke = svgColor(node.style.strokeColor ?? .system(.systemGray))
        let transform = node.rotation == 0 ? "" : " transform=\"rotate(\(fmt(node.rotation * 180 / .pi)) \(fmt(node.frame.center.x)) \(fmt(node.frame.center.y)))\""

        var result = "<path d=\"\(svgPathData(path))\" fill=\"\(fill)\" stroke=\"\(stroke)\" " +
            "stroke-width=\"\(fmt(node.style.strokeWidth))\" opacity=\"\(fmt(node.style.opacity))\"\(transform)/>\n"

        if let text = node.text, !text.string.isEmpty {
            let fontSize = fmt(node.style.font?.size ?? 13)
            result += "<text x=\"\(fmt(node.frame.center.x))\" y=\"\(fmt(node.frame.center.y))\" " +
                "text-anchor=\"middle\" dominant-baseline=\"middle\" font-size=\"\(fontSize)\" " +
                "font-family=\"-apple-system, sans-serif\" fill=\"#000000\"\(transform)>\(xmlEscape(text.string))</text>\n"
        }
        return result
    }

    private static func svgForEdge(_ edge: DiagramEdge, nodes: [NodeID: DiagramNode]) -> String {
        guard !edge.isHidden else { return "" }
        let targetAim = aimPoint(for: edge.target, nodes: nodes)
        let sourceAim = aimPoint(for: edge.source, nodes: nodes)
        guard let source = EdgeGeometry.resolvedPoint(for: edge.source, nodes: nodes, towards: targetAim),
              let target = EdgeGeometry.resolvedPoint(for: edge.target, nodes: nodes, towards: sourceAim) else { return "" }

        let stroke = svgColor(edge.style.strokeColor ?? .system(.systemGray))
        let path = EdgeGeometry.path(from: source, to: target, routing: edge.routing)
        var result = "<path d=\"\(svgPathData(path))\" fill=\"none\" stroke=\"\(stroke)\" stroke-width=\"\(fmt(edge.style.strokeWidth))\"/>\n"

        result += svgForArrowhead(from: target, tip: source, style: edge.style.startArrow, stroke: stroke)
        result += svgForArrowhead(from: source, tip: target, style: edge.style.endArrow, stroke: stroke)
        return result
    }

    private static func svgForArrowhead(from: CGPoint, tip: CGPoint, style: ArrowheadStyle, stroke: String) -> String {
        guard let path = EdgeGeometry.arrowheadPath(from: from, tip: tip, style: style) else { return "" }
        let filled = style == .filled || style == .diamond || style == .circle
        return "<path d=\"\(svgPathData(path))\" fill=\"\(filled ? stroke : "none")\" stroke=\"\(stroke)\"/>\n"
    }

    private static func aimPoint(for endpoint: EndpointRef, nodes: [NodeID: DiagramNode]) -> CGPoint {
        switch endpoint {
        case .point(let p): return CGPoint(x: p.x, y: p.y)
        case .node(let id, _): return nodes[id]?.frame.center ?? .zero
        }
    }

    private static func svgPathData(_ path: CGPath) -> String {
        var d = ""
        path.applyWithBlock { elementPtr in
            let element = elementPtr.pointee
            switch element.type {
            case .moveToPoint:
                d += "M\(fmt(element.points[0].x)) \(fmt(element.points[0].y)) "
            case .addLineToPoint:
                d += "L\(fmt(element.points[0].x)) \(fmt(element.points[0].y)) "
            case .addQuadCurveToPoint:
                d += "Q\(fmt(element.points[0].x)) \(fmt(element.points[0].y)) \(fmt(element.points[1].x)) \(fmt(element.points[1].y)) "
            case .addCurveToPoint:
                d += "C\(fmt(element.points[0].x)) \(fmt(element.points[0].y)) " +
                    "\(fmt(element.points[1].x)) \(fmt(element.points[1].y)) " +
                    "\(fmt(element.points[2].x)) \(fmt(element.points[2].y)) "
            case .closeSubpath:
                d += "Z "
            @unknown default:
                break
            }
        }
        return d
    }

    private static func svgColor(_ ref: ColorRef) -> String {
        let r = Int((ref.red * 255).rounded()), g = Int((ref.green * 255).rounded()), b = Int((ref.blue * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    private static func xmlEscape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func fmt(_ value: Double) -> String { String(format: "%.2f", value) }
    private static func fmt(_ value: CGFloat) -> String { String(format: "%.2f", Double(value)) }
}
