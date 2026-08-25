import CoreGraphics
import DiagramModel

extension ShapeGeometry {
    static func bpmnPath(for type: ShapeType, in rect: CGRect) -> CGPath {
        switch type {
        case .bpmnStartEvent, .bpmnEndEvent:
            // Thin vs. thick border is a stroke-width concern (the
            // sidebar's default style differs per type), not geometry.
            let side = min(rect.width, rect.height)
            let square = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
            return CGPath(ellipseIn: square, transform: nil)

        case .bpmnIntermediateEvent:
            return concentricArcs(in: rect, ringCount: 2)

        case .bpmnTask:
            return CGPath(roundedRect: rect, cornerWidth: 10, cornerHeight: 10, transform: nil)

        case .bpmnGateway:
            return polygon([
                CGPoint(x: rect.midX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.midY),
                CGPoint(x: rect.midX, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.midY)
            ])

        case .bpmnPool:
            // Vertical header band on the left.
            let headerWidth = min(rect.width * 0.15, 28)
            let path = CGMutablePath()
            path.addRect(rect)
            path.move(to: CGPoint(x: rect.minX + headerWidth, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + headerWidth, y: rect.maxY))
            return path

        case .bpmnLane:
            // Horizontal header band on top.
            let headerHeight = min(rect.height * 0.2, 24)
            let path = CGMutablePath()
            path.addRect(rect)
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + headerHeight))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + headerHeight))
            return path

        case .bpmnDataObject:
            // Rectangle with a folded top-right corner.
            let fold = min(rect.width, rect.height) * 0.25
            let path = CGMutablePath()
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + fold))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
            path.move(to: CGPoint(x: rect.maxX - fold, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.minY + fold))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + fold))
            return path

        default:
            return CGPath(rect: rect, transform: nil)
        }
    }
}
