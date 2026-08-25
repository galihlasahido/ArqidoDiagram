import CoreGraphics
import DiagramModel

extension ShapeGeometry {
    static func c4Path(for type: ShapeType, in rect: CGRect) -> CGPath {
        switch type {
        case .c4Person:
            return personPath(in: rect)

        // Software System / Container / Component / External System share
        // one rounded-rect geometry in real C4 diagrams too — the
        // distinguishing information is color/label, not shape.
        case .c4SoftwareSystem, .c4Container, .c4Component, .c4ExternalSystem:
            return CGPath(roundedRect: rect, cornerWidth: 10, cornerHeight: 10, transform: nil)

        default:
            return CGPath(rect: rect, transform: nil)
        }
    }
}
