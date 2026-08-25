import CoreGraphics
import DiagramModel

/// Builds the `CGPath` for a shape type in a given rect. Shared by drawing
/// (`DiagramCanvasView`) and exact hit-testing (once selection lands) so
/// the two never drift apart. No `NSView`/`NSGraphicsContext` dependency —
/// pure geometry, unit-testable in plain XCTest.
public enum ShapeGeometry {
    public static func path(for type: ShapeType, in rect: CGRect) -> CGPath {
        switch type {
        case .rectangle, .image, .container, .flowchartProcess, .flowchartSubprocess:
            return CGPath(rect: rect, transform: nil)

        case .roundedRectangle, .text, .stickyNote:
            return CGPath(
                roundedRect: rect,
                cornerWidth: min(8, rect.width / 4),
                cornerHeight: min(8, rect.height / 4),
                transform: nil
            )

        case .circle:
            let side = min(rect.width, rect.height)
            let square = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
            return CGPath(ellipseIn: square, transform: nil)

        case .ellipse:
            return CGPath(ellipseIn: rect, transform: nil)

        case .diamond, .flowchartDecision:
            return polygon([
                CGPoint(x: rect.midX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.midY),
                CGPoint(x: rect.midX, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.midY)
            ])

        case .triangle:
            return polygon([
                CGPoint(x: rect.midX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.maxY)
            ])

        case .hexagon:
            let inset = rect.width * 0.2
            return polygon([
                CGPoint(x: rect.minX + inset, y: rect.minY),
                CGPoint(x: rect.maxX - inset, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.midY),
                CGPoint(x: rect.maxX - inset, y: rect.maxY),
                CGPoint(x: rect.minX + inset, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.midY)
            ])

        case .star:
            return starPath(in: rect, points: 5)

        case .line, .arrow:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            return path

        case .flowchartStartEnd:
            let radius = rect.height / 2
            return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

        case .flowchartInputOutput:
            let skew = rect.width * 0.15
            return polygon([
                CGPoint(x: rect.minX + skew, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.minY),
                CGPoint(x: rect.maxX - skew, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.maxY)
            ])

        case .flowchartManualProcess:
            let inset = rect.width * 0.15
            return polygon([
                CGPoint(x: rect.minX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.minY),
                CGPoint(x: rect.maxX - inset, y: rect.maxY),
                CGPoint(x: rect.minX + inset, y: rect.maxY)
            ])

        case .flowchartDocument:
            return documentPath(in: rect)

        case .flowchartDatabase:
            return cylinderPath(in: rect)

        case .umlClass, .umlInterface, .umlActor, .umlUseCase, .umlComponent, .umlPackage,
             .umlSequenceLifeline, .umlActivity, .umlState, .umlDeploymentNode:
            return umlPath(for: type, in: rect)

        case .c4Person, .c4SoftwareSystem, .c4Container, .c4Component, .c4ExternalSystem:
            return c4Path(for: type, in: rect)

        case .erdEntity, .erdAttribute, .erdPrimaryKey, .erdForeignKey:
            return erdPath(for: type, in: rect)

        case .bpmnStartEvent, .bpmnIntermediateEvent, .bpmnEndEvent, .bpmnTask, .bpmnGateway,
             .bpmnPool, .bpmnLane, .bpmnDataObject:
            return bpmnPath(for: type, in: rect)

        case .networkRouter, .networkSwitch, .networkFirewall, .networkLoadBalancer, .networkServer,
             .networkNAS, .networkWiFi, .networkVPN, .networkProxy, .networkGateway, .networkDNS,
             .networkInternet, .networkLaptop, .networkDesktop, .networkMobile, .networkIoT:
            return networkPath(for: type, in: rect)

        case .securityWAF, .securityIDS, .securityIPS, .securitySIEM, .securitySOC, .securityIAM,
             .securityMFA, .securityHSM, .securityKMS, .securityCertificateAuthority, .securityDLP,
             .securityZeroTrust:
            return securityPath(for: type, in: rect)
        }
    }

    static func polygon(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }

    static func starPath(in rect: CGRect, points: Int) -> CGPath {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.4
        let path = CGMutablePath()
        let angleStep = CGFloat.pi / CGFloat(points)

        for i in 0..<(points * 2) {
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            // Start pointing up (-90deg) so the star reads "upright".
            let angle = angleStep * CGFloat(i) - .pi / 2
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    /// Rectangle with a single wavy scallop along the bottom edge.
    static func documentPath(in rect: CGRect) -> CGPath {
        let waveDepth = min(rect.height * 0.15, 12)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - waveDepth))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - waveDepth),
            control1: CGPoint(x: rect.maxX - rect.width * 0.25, y: rect.maxY + waveDepth),
            control2: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.maxY - waveDepth * 2)
        )
        path.closeSubpath()
        return path
    }

    /// Cylinder: ellipse cap on top, straight sides, ellipse cap on bottom.
    static func cylinderPath(in rect: CGRect) -> CGPath {
        let capHeight = min(rect.height * 0.2, 16)
        let topCapRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: capHeight * 2)
        let bottomCapRect = CGRect(x: rect.minX, y: rect.maxY - capHeight * 2, width: rect.width, height: capHeight * 2)

        let path = CGMutablePath()
        path.addEllipse(in: topCapRect)
        path.addEllipse(in: bottomCapRect)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + capHeight))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - capHeight))
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY + capHeight))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - capHeight))
        return path
    }
}
