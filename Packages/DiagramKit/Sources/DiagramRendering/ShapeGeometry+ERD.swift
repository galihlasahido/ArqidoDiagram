import CoreGraphics
import DiagramModel

extension ShapeGeometry {
    static func erdPath(for type: ShapeType, in rect: CGRect) -> CGPath {
        switch type {
        case .erdEntity:
            return CGPath(rect: rect, transform: nil)

        case .erdAttribute:
            return CGPath(ellipseIn: rect, transform: nil)

        case .erdPrimaryKey:
            // Chen notation: oval with a solid underline.
            let path = CGMutablePath()
            path.addEllipse(in: rect)
            let underlineY = rect.maxY - rect.height * 0.22
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.2, y: underlineY))
            path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.2, y: underlineY))
            return path

        case .erdForeignKey:
            // A dashed-look underline (two short segments) distinguishes it
            // from the primary key's solid one without needing real dash
            // support on node strokes.
            let path = CGMutablePath()
            path.addEllipse(in: rect)
            let underlineY = rect.maxY - rect.height * 0.22
            let startX = rect.minX + rect.width * 0.2
            let endX = rect.maxX - rect.width * 0.2
            let mid = (startX + endX) / 2
            let gap = (endX - startX) * 0.15
            path.move(to: CGPoint(x: startX, y: underlineY))
            path.addLine(to: CGPoint(x: mid - gap, y: underlineY))
            path.move(to: CGPoint(x: mid + gap, y: underlineY))
            path.addLine(to: CGPoint(x: endX, y: underlineY))
            return path

        default:
            return CGPath(rect: rect, transform: nil)
        }
    }
}
