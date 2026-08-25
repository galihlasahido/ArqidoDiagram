import CoreGraphics
import DiagramModel

extension ShapeGeometry {
    static func umlPath(for type: ShapeType, in rect: CGRect) -> CGPath {
        switch type {
        case .umlClass:
            // Name / attributes / methods compartments.
            return dividedRectangle(in: rect, dividerFractions: [0.33, 0.66])

        case .umlInterface:
            let side = min(rect.width, rect.height) * 0.5
            let square = CGRect(x: rect.midX - side / 2, y: rect.minY, width: side, height: side)
            return CGPath(ellipseIn: square, transform: nil)

        case .umlActor:
            return personPath(in: rect)

        case .umlUseCase:
            return CGPath(ellipseIn: rect, transform: nil)

        case .umlComponent:
            let path = CGMutablePath()
            path.addRect(rect)
            let tabWidth = rect.width * 0.15
            let tabHeight = rect.height * 0.15
            let tab1 = CGRect(x: rect.minX - tabWidth / 2, y: rect.minY + rect.height * 0.2, width: tabWidth, height: tabHeight)
            let tab2 = CGRect(x: rect.minX - tabWidth / 2, y: rect.minY + rect.height * 0.6, width: tabWidth, height: tabHeight)
            path.addRect(tab1)
            path.addRect(tab2)
            return path

        case .umlPackage:
            let tabWidth = rect.width * 0.4
            let tabHeight = rect.height * 0.2
            let path = CGMutablePath()
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + tabHeight))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + tabWidth, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + tabWidth, y: rect.minY + tabHeight))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + tabHeight))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
            return path

        case .umlSequenceLifeline:
            let headerHeight = min(rect.height * 0.3, 40)
            let path = CGMutablePath()
            path.addRect(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: headerHeight))
            path.move(to: CGPoint(x: rect.midX, y: rect.minY + headerHeight))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            return path

        case .umlActivity:
            return CGPath(roundedRect: rect, cornerWidth: rect.height * 0.4, cornerHeight: rect.height * 0.4, transform: nil)

        case .umlState:
            return CGPath(roundedRect: rect, cornerWidth: rect.height * 0.5, cornerHeight: rect.height * 0.5, transform: nil)

        case .umlDeploymentNode:
            let depth = min(rect.width, rect.height) * 0.2
            let front = CGRect(x: rect.minX, y: rect.minY + depth, width: rect.width - depth, height: rect.height - depth)
            let path = CGMutablePath()
            path.addRect(front)
            // Top face.
            path.move(to: CGPoint(x: front.minX, y: front.minY))
            path.addLine(to: CGPoint(x: front.minX + depth, y: front.minY - depth))
            path.addLine(to: CGPoint(x: front.maxX + depth, y: front.minY - depth))
            path.addLine(to: CGPoint(x: front.maxX, y: front.minY))
            path.closeSubpath()
            // Side face.
            path.move(to: CGPoint(x: front.maxX, y: front.minY))
            path.addLine(to: CGPoint(x: front.maxX + depth, y: front.minY - depth))
            path.addLine(to: CGPoint(x: front.maxX + depth, y: front.maxY - depth))
            path.addLine(to: CGPoint(x: front.maxX, y: front.maxY))
            path.closeSubpath()
            return path

        default:
            return CGPath(rect: rect, transform: nil)
        }
    }
}
