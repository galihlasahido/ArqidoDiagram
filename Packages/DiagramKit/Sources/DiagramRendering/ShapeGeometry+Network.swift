import CoreGraphics
import DiagramModel

extension ShapeGeometry {
    static func networkPath(for type: ShapeType, in rect: CGRect) -> CGPath {
        switch type {
        case .networkRouter:
            let path = CGMutablePath()
            let side = min(rect.width, rect.height) * 0.6
            let square = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
            path.addEllipse(in: square)
            // 4 radiating tick marks.
            for angle in stride(from: 0.0, to: 2 * Double.pi, by: .pi / 2) {
                let inner = CGPoint(x: rect.midX + side / 2 * CGFloat(cos(angle)), y: rect.midY + side / 2 * CGFloat(sin(angle)))
                let outer = CGPoint(x: rect.midX + (side / 2 + 8) * CGFloat(cos(angle)), y: rect.midY + (side / 2 + 8) * CGFloat(sin(angle)))
                path.move(to: inner)
                path.addLine(to: outer)
            }
            return path

        case .networkSwitch:
            let path = CGMutablePath()
            path.addRect(rect)
            let tickCount = 4
            for i in 0..<tickCount {
                let x = rect.minX + rect.width * (CGFloat(i) + 0.5) / CGFloat(tickCount)
                path.move(to: CGPoint(x: x, y: rect.minY))
                path.addLine(to: CGPoint(x: x, y: rect.minY - 6))
                path.move(to: CGPoint(x: x, y: rect.maxY))
                path.addLine(to: CGPoint(x: x, y: rect.maxY + 6))
            }
            return path

        case .networkFirewall:
            // Simplified brick-wall pattern.
            let path = CGMutablePath()
            path.addRect(rect)
            let rows = 3
            for row in 0..<rows {
                let y = rect.minY + rect.height * CGFloat(row + 1) / CGFloat(rows + 1)
                path.move(to: CGPoint(x: rect.minX, y: y))
                path.addLine(to: CGPoint(x: rect.maxX, y: y))
            }
            let offsetCols = 3
            for row in 0..<(rows + 1) {
                let rowOffset: CGFloat = row.isMultiple(of: 2) ? 0 : rect.width / CGFloat(offsetCols) / 2
                let rowTop = rect.minY + rect.height * CGFloat(row) / CGFloat(rows + 1)
                let rowBottom = rect.minY + rect.height * CGFloat(row + 1) / CGFloat(rows + 1)
                for col in 1..<offsetCols {
                    let x = rect.minX + rowOffset + rect.width * CGFloat(col) / CGFloat(offsetCols)
                    guard x > rect.minX, x < rect.maxX else { continue }
                    path.move(to: CGPoint(x: x, y: rowTop))
                    path.addLine(to: CGPoint(x: x, y: rowBottom))
                }
            }
            return path

        case .networkLoadBalancer:
            let path = CGMutablePath()
            path.addRect(rect)
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.midY))
            path.move(to: CGPoint(x: rect.midX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.2))
            path.move(to: CGPoint(x: rect.midX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.2))
            return path

        case .networkServer:
            return dividedRectangle(in: rect, dividerFractions: [0.25, 0.5, 0.75])

        case .networkNAS:
            return cylinderPath(in: rect)

        case .networkWiFi:
            return concentricArcs(in: rect, ringCount: 3, fullCircle: false)

        case .networkVPN:
            return shieldPath(in: rect)

        case .networkProxy:
            let path = CGMutablePath()
            path.addRect(rect)
            let y1 = rect.minY + rect.height * 0.35
            let y2 = rect.minY + rect.height * 0.65
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.15, y: y1))
            path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.15, y: y1))
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.15, y: y2))
            path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.15, y: y2))
            return path

        case .networkGateway:
            let path = CGMutablePath()
            path.addRect(rect)
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.3, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.35, y: rect.midY - rect.height * 0.15))
            path.move(to: CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.35, y: rect.midY + rect.height * 0.15))
            return path

        case .networkDNS:
            return CGPath(roundedRect: rect, cornerWidth: 8, cornerHeight: 8, transform: nil)

        case .networkInternet:
            let path = CGMutablePath()
            let side = min(rect.width, rect.height)
            let square = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
            path.addEllipse(in: square)
            path.addEllipse(in: CGRect(x: square.minX, y: square.midY - side * 0.18, width: side, height: side * 0.36))
            path.move(to: CGPoint(x: square.midX, y: square.minY))
            path.addLine(to: CGPoint(x: square.midX, y: square.maxY))
            return path

        case .networkLaptop:
            let path = CGMutablePath()
            let screenHeight = rect.height * 0.7
            let screenRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: screenHeight)
            path.addRect(screenRect)
            path.move(to: CGPoint(x: rect.minX - rect.width * 0.1, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX + rect.width * 0.1, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: screenRect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: screenRect.maxY))
            path.closeSubpath()
            return path

        case .networkDesktop:
            let path = CGMutablePath()
            let screenHeight = rect.height * 0.65
            path.addRect(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: screenHeight))
            let standWidth = rect.width * 0.3
            path.addRect(CGRect(x: rect.midX - standWidth / 2, y: rect.minY + screenHeight, width: standWidth, height: rect.height - screenHeight))
            return path

        case .networkMobile:
            return CGPath(roundedRect: rect, cornerWidth: rect.width * 0.25, cornerHeight: rect.width * 0.25, transform: nil)

        case .networkIoT:
            return concentricArcs(in: rect, ringCount: 2, fullCircle: false)

        default:
            return CGPath(rect: rect, transform: nil)
        }
    }
}
