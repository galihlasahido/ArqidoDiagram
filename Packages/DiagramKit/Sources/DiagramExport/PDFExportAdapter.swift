import CoreGraphics
import Foundation
import DiagramModel
import DiagramRendering

public enum PDFExportAdapter {
    public static func write(_ page: DiagramPage, to url: URL, padding: CGFloat = 40) async throws {
        try await Task.detached(priority: .userInitiated) {
            try render(page: page, to: url, padding: padding)
        }.value
    }

    private static func render(page: DiagramPage, to url: URL, padding: CGFloat) throws {
        let bounds = PageRenderer.contentBounds(of: page).insetBy(dx: -padding, dy: -padding)
        var mediaBox = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)

        guard let consumer = CGDataConsumer(url: url as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw ExportError.invalidContext
        }

        context.beginPDFPage(nil as CFDictionary?)
        // Same Y-down-content-into-Y-up-Quartz-page flip as PNGExportAdapter.
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        context.translateBy(x: -bounds.minX, y: -bounds.minY)
        PageRenderer.draw(page, in: context, scale: 1)
        context.endPDFPage()
        context.closePDF()
    }
}
