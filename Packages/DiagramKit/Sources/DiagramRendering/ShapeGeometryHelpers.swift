import CoreGraphics

/// Shared composition helpers used across the Phase 2 shape libraries
/// (UML/C4/ERD/BPMN/Network/Security) — small geometric building blocks
/// (dividers, shields, arcs, chip pins) combined per shape, rather than
/// hand-copying real vendor icons (see each library file's own doc comment
/// on why these are honest generic vectors, not AWS/Azure/etc. logos).
extension ShapeGeometry {
    /// A rectangle with horizontal divider lines at the given fractional
    /// heights (0...1) — UML class compartments, server rack units, etc.
    /// The dividers are open subpaths, so they stroke as lines without
    /// contributing extra fill area.
    static func dividedRectangle(in rect: CGRect, dividerFractions: [CGFloat]) -> CGPath {
        let path = CGMutablePath()
        path.addRect(rect)
        for fraction in dividerFractions {
            let y = rect.minY + rect.height * fraction
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return path
    }

    /// A simple shield outline (flat top, pointed bottom) — VPN/WAF/Zero
    /// Trust/MFA all read as "security" via this family shape.
    static func shieldPath(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.15))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.15))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.55))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.85),
            control2: CGPoint(x: rect.midX + rect.width * 0.15, y: rect.maxY - rect.height * 0.1)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.55),
            control1: CGPoint(x: rect.midX - rect.width * 0.15, y: rect.maxY - rect.height * 0.1),
            control2: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.85)
        )
        path.closeSubpath()
        return path
    }

    /// A person silhouette (head circle + rounded-shoulder body) — UML
    /// Actor, C4 Person.
    static func personPath(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let headDiameter = rect.width * 0.5
        let headRect = CGRect(x: rect.midX - headDiameter / 2, y: rect.minY, width: headDiameter, height: headDiameter)
        path.addEllipse(in: headRect)

        let bodyTop = headRect.maxY + rect.height * 0.05
        let bodyRect = CGRect(x: rect.minX, y: bodyTop, width: rect.width, height: rect.maxY - bodyTop)
        path.move(to: CGPoint(x: bodyRect.minX, y: bodyRect.maxY))
        path.addCurve(
            to: CGPoint(x: bodyRect.maxX, y: bodyRect.maxY),
            control1: CGPoint(x: bodyRect.minX, y: bodyRect.minY),
            control2: CGPoint(x: bodyRect.maxX, y: bodyRect.minY)
        )
        return path
    }

    /// Concentric circles (2 or 3 rings) — BPMN intermediate event, radar/
    /// signal-style marks (WiFi, IoT, KMS).
    static func concentricArcs(in rect: CGRect, ringCount: Int, fullCircle: Bool = true) -> CGPath {
        let path = CGMutablePath()
        let maxRadius = min(rect.width, rect.height) / 2
        let center = rect.center
        for i in 0..<ringCount {
            let radius = maxRadius * CGFloat(i + 1) / CGFloat(ringCount)
            let ringRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            if fullCircle {
                path.addEllipse(in: ringRect)
            } else {
                path.addArc(center: center, radius: radius, startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
            }
        }
        return path
    }

    /// A small checkmark, for badge accents (MFA, validated states).
    static func checkmarkPath(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.maxY - rect.height * 0.2))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.15, y: rect.minY + rect.height * 0.2))
        return path
    }
}
