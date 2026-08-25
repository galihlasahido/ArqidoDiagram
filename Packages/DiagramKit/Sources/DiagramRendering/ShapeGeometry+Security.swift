import CoreGraphics
import DiagramModel

extension ShapeGeometry {
    static func securityPath(for type: ShapeType, in rect: CGRect) -> CGPath {
        switch type {
        case .securityWAF, .securityZeroTrust:
            let path = CGMutablePath()
            path.addPath(shieldPath(in: rect))
            if type == .securityZeroTrust {
                // Checkerboard accent inside the shield.
                let inset = rect.insetBy(dx: rect.width * 0.25, dy: rect.height * 0.3)
                for i in 0...2 {
                    let x = inset.minX + inset.width * CGFloat(i) / 2
                    path.move(to: CGPoint(x: x, y: inset.minY))
                    path.addLine(to: CGPoint(x: x, y: inset.maxY))
                }
            }
            return path

        case .securityIDS, .securityIPS:
            // Eye: lens (two arcs) + pupil circle.
            let path = CGMutablePath()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control: CGPoint(x: rect.midX, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.midY), control: CGPoint(x: rect.midX, y: rect.maxY))
            let pupilRadius = min(rect.width, rect.height) * 0.15
            path.addEllipse(in: CGRect(x: rect.midX - pupilRadius, y: rect.midY - pupilRadius, width: pupilRadius * 2, height: pupilRadius * 2))
            return path

        case .securitySIEM:
            let path = CGMutablePath()
            path.addRect(rect)
            let barWidths: [CGFloat] = [0.4, 0.7, 0.55]
            for (i, heightFraction) in barWidths.enumerated() {
                let barWidth = rect.width * 0.15
                let x = rect.minX + rect.width * (CGFloat(i) + 0.5) / 4
                let barHeight = rect.height * 0.6 * heightFraction
                path.addRect(CGRect(x: x - barWidth / 2, y: rect.maxY - rect.height * 0.15 - barHeight, width: barWidth, height: barHeight))
            }
            return path

        case .securitySOC:
            let path = CGMutablePath()
            path.addRect(rect)
            let radius = min(rect.width, rect.height) * 0.12
            path.addEllipse(in: CGRect(x: rect.midX - radius * 2.2, y: rect.midY - radius, width: radius * 2, height: radius * 2))
            path.addEllipse(in: CGRect(x: rect.midX + radius * 0.2, y: rect.midY - radius, width: radius * 2, height: radius * 2))
            return path

        case .securityIAM, .securityKMS:
            let path = CGMutablePath()
            let side = min(rect.width, rect.height) * 0.55
            let square = CGRect(x: rect.minX, y: rect.midY - side / 2, width: side, height: side)
            path.addEllipse(in: square)
            if type == .securityIAM {
                path.move(to: CGPoint(x: square.maxX, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
                path.move(to: CGPoint(x: rect.maxX - rect.width * 0.1, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.1, y: rect.midY + rect.height * 0.15))
            } else {
                for radius in stride(from: side * 0.7, to: side * 1.3, by: side * 0.3) {
                    path.addArc(center: rect.center, radius: radius, startAngle: -.pi / 4, endAngle: .pi / 4, clockwise: false)
                }
            }
            return path

        case .securityMFA:
            let path = CGMutablePath()
            path.addPath(shieldPath(in: rect))
            path.addPath(checkmarkPath(in: rect))
            return path

        case .securityHSM:
            let path = CGMutablePath()
            let inset = rect.insetBy(dx: rect.width * 0.15, dy: rect.height * 0.15)
            path.addRect(inset)
            let pinCount = 3
            for i in 0..<pinCount {
                let x = inset.minX + inset.width * (CGFloat(i) + 0.5) / CGFloat(pinCount)
                path.move(to: CGPoint(x: x, y: rect.minY))
                path.addLine(to: CGPoint(x: x, y: inset.minY))
                path.move(to: CGPoint(x: x, y: inset.maxY))
                path.addLine(to: CGPoint(x: x, y: rect.maxY))
            }
            for i in 0..<pinCount {
                let y = inset.minY + inset.height * (CGFloat(i) + 0.5) / CGFloat(pinCount)
                path.move(to: CGPoint(x: rect.minX, y: y))
                path.addLine(to: CGPoint(x: inset.minX, y: y))
                path.move(to: CGPoint(x: inset.maxX, y: y))
                path.addLine(to: CGPoint(x: rect.maxX, y: y))
            }
            return path

        case .securityCertificateAuthority:
            let path = CGMutablePath()
            let radius = min(rect.width, rect.height) * 0.4
            let sealRect = CGRect(x: rect.midX - radius, y: rect.minY, width: radius * 2, height: radius * 2)
            path.addEllipse(in: sealRect)
            path.move(to: CGPoint(x: rect.midX - radius * 0.4, y: sealRect.maxY - radius * 0.2))
            path.addLine(to: CGPoint(x: rect.midX - radius * 0.6, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - radius * 0.4))
            path.addLine(to: CGPoint(x: rect.midX + radius * 0.6, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX + radius * 0.4, y: sealRect.maxY - radius * 0.2))
            path.closeSubpath()
            return path

        case .securityDLP:
            // Octagon (stop-sign silhouette).
            let inset = rect.width * 0.15
            return polygon([
                CGPoint(x: rect.minX + inset, y: rect.minY),
                CGPoint(x: rect.maxX - inset, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.minY + inset),
                CGPoint(x: rect.maxX, y: rect.maxY - inset),
                CGPoint(x: rect.maxX - inset, y: rect.maxY),
                CGPoint(x: rect.minX + inset, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.maxY - inset),
                CGPoint(x: rect.minX, y: rect.minY + inset)
            ])

        default:
            return CGPath(rect: rect, transform: nil)
        }
    }
}
