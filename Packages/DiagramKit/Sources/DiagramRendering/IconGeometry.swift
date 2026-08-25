import CoreGraphics
import DiagramModel

/// Small badge glyphs drawn over a node's shape when `DiagramNode.iconType`
/// is set (see `PageRenderer.drawNode`). Each vendor pack (AWS/Azure/GCP)
/// shares one glyph per underlying concept — compute, storage, etc. read
/// the same regardless of vendor, exactly like the real icon does not
/// change meaning across packs — with the pack itself only distinguishing
/// which catalog entry/tags apply (see `TechIconCatalog`). This keeps the
/// glyph set small and honest: original shapes, not vendor artwork.
enum IconGeometry {
    private enum Concept {
        case compute, storage, database, container, function
        case pod, service, deployment, cluster, ingress, configMap
    }

    private static func concept(for type: TechIconType) -> Concept {
        switch type {
        case .awsCompute, .azureCompute, .gcpCompute: return .compute
        case .awsStorage, .azureStorage, .gcpStorage: return .storage
        case .awsDatabase, .azureDatabase, .gcpDatabase: return .database
        case .awsContainer, .azureContainer, .gcpContainer: return .container
        case .awsFunction, .azureFunction, .gcpFunction: return .function
        case .kubernetesPod: return .pod
        case .kubernetesService: return .service
        case .kubernetesDeployment: return .deployment
        case .kubernetesCluster: return .cluster
        case .kubernetesIngress: return .ingress
        case .kubernetesConfigMap: return .configMap
        }
    }

    static func path(for type: TechIconType, in rect: CGRect) -> CGPath {
        switch concept(for: type) {
        case .compute:
            let path = CGMutablePath()
            path.addPath(CGPath(roundedRect: rect, cornerWidth: rect.width * 0.15, cornerHeight: rect.width * 0.15, transform: nil))
            let dotRadius = rect.width * 0.08
            let dotRect = CGRect(x: rect.maxX - dotRadius * 3, y: rect.maxY - dotRadius * 3, width: dotRadius * 2, height: dotRadius * 2)
            path.addEllipse(in: dotRect)
            return path

        case .storage:
            return ShapeGeometry.cylinderPath(in: rect)

        case .database:
            let path = CGMutablePath()
            path.addPath(ShapeGeometry.cylinderPath(in: rect))
            let midY = rect.midY
            path.move(to: CGPoint(x: rect.minX, y: midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: midY))
            return path

        case .container:
            return containerCratePath(in: rect)

        case .function:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: rect.midX + rect.width * 0.12, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.midY + rect.height * 0.05))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.05))
            path.addLine(to: CGPoint(x: rect.midX - rect.width * 0.12, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.midY - rect.height * 0.05))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.midY - rect.height * 0.05))
            path.closeSubpath()
            return path

        case .pod:
            let inset = rect.width * 0.15
            return ShapeGeometry.polygon([
                CGPoint(x: rect.minX + inset, y: rect.minY),
                CGPoint(x: rect.maxX - inset, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.midY),
                CGPoint(x: rect.maxX - inset, y: rect.maxY),
                CGPoint(x: rect.minX + inset, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.midY)
            ])

        case .service:
            let path = CGMutablePath()
            let radius = min(rect.width, rect.height) * 0.2
            path.addEllipse(in: CGRect(x: rect.midX - radius, y: rect.midY - radius, width: radius * 2, height: radius * 2))
            for angle in stride(from: 0.0, to: 2 * Double.pi, by: .pi / 2) {
                let outer = CGPoint(
                    x: rect.midX + min(rect.width, rect.height) / 2 * CGFloat(cos(angle)),
                    y: rect.midY + min(rect.width, rect.height) / 2 * CGFloat(sin(angle))
                )
                let inner = CGPoint(x: rect.midX + radius * CGFloat(cos(angle)), y: rect.midY + radius * CGFloat(sin(angle)))
                path.move(to: inner)
                path.addLine(to: outer)
            }
            return path

        case .deployment:
            let path = CGMutablePath()
            let layerHeight = rect.height * 0.28
            for i in 0..<3 {
                let y = rect.minY + CGFloat(i) * (rect.height - layerHeight) / 2
                let layerRect = CGRect(x: rect.minX, y: y, width: rect.width, height: layerHeight)
                path.addPath(CGPath(roundedRect: layerRect, cornerWidth: 3, cornerHeight: 3, transform: nil))
            }
            return path

        case .cluster:
            let path = CGMutablePath()
            let cellSize = min(rect.width, rect.height) * 0.35
            let positions = [
                CGPoint(x: rect.minX + cellSize / 2, y: rect.minY + cellSize / 2),
                CGPoint(x: rect.maxX - cellSize / 2, y: rect.minY + cellSize / 2),
                CGPoint(x: rect.minX + cellSize / 2, y: rect.maxY - cellSize / 2),
                CGPoint(x: rect.maxX - cellSize / 2, y: rect.maxY - cellSize / 2)
            ]
            for center in positions {
                path.addEllipse(in: CGRect(x: center.x - cellSize / 2, y: center.y - cellSize / 2, width: cellSize, height: cellSize))
            }
            return path

        case .ingress:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX + rect.width * 0.15, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX + rect.width * 0.15, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX - rect.width * 0.15, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX - rect.width * 0.15, y: rect.midY))
            path.closeSubpath()
            return path

        case .configMap:
            let path = CGMutablePath()
            path.addPath(ShapeGeometry.documentPath(in: rect))
            let lineInset = rect.width * 0.2
            for fraction: CGFloat in [0.35, 0.55] {
                let y = rect.minY + rect.height * fraction
                path.move(to: CGPoint(x: rect.minX + lineInset, y: y))
                path.addLine(to: CGPoint(x: rect.maxX - lineInset, y: y))
            }
            return path
        }
    }

    /// A simple packing-crate glyph: outer box + one horizontal + one
    /// vertical divider, read as "bundled/packaged" for container services.
    private static func containerCratePath(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        path.addRect(rect)
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}
