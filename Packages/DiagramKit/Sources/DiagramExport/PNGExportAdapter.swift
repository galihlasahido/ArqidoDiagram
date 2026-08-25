import AppKit
import DiagramModel
import DiagramRendering

/// Reuses `PageRenderer` (the same drawing code the live canvas uses) so
/// exported output matches on-screen rendering exactly. Runs off the main
/// thread via `Task.detached` — per the spec's "never block the main UI
/// thread for expensive operations."
public enum PNGExportAdapter {
    public static func data(for page: DiagramPage, padding: CGFloat = 40, scale: CGFloat = 2) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            try render(page: page, padding: padding, scale: scale)
        }.value
    }

    public static func write(_ page: DiagramPage, to url: URL, padding: CGFloat = 40, scale: CGFloat = 2) async throws {
        let data = try await data(for: page, padding: padding, scale: scale)
        try data.write(to: url, options: .atomic)
    }

    private static func render(page: DiagramPage, padding: CGFloat, scale: CGFloat) throws -> Data {
        let bounds = PageRenderer.contentBounds(of: page).insetBy(dx: -padding, dy: -padding)
        let pixelWidth = max(1, Int((bounds.width * scale).rounded(.up)))
        let pixelHeight = max(1, Int((bounds.height * scale).rounded(.up)))

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixelWidth, pixelsHigh: pixelHeight,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: rep) else {
            throw ExportError.invalidContext
        }

        let cg = context.cgContext
        cg.setFillColor(NSColor.white.cgColor)
        cg.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        // PageRenderer/ShapeGeometry assume a Y-down content space (matching
        // DiagramCanvasView's `isFlipped == true`); a fresh bitmap context's
        // native CTM is Y-up (Quartz convention), so flip before applying
        // the export scale/content-origin translate.
        cg.translateBy(x: 0, y: CGFloat(pixelHeight))
        cg.scaleBy(x: scale, y: -scale)
        cg.translateBy(x: -bounds.minX, y: -bounds.minY)

        PageRenderer.draw(page, in: cg, scale: scale)

        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw ExportError.encodingFailed
        }
        return data
    }
}
