import AppKit
import UniformTypeIdentifiers
import CoreText
import DiagramModel
import DiagramInterop

/// Spec §21 "Documentation": Export: Markdown, HTML, PDF. Markdown/HTML
/// come straight from `DiagramInterop.DocumentationGenerator`; PDF renders
/// that same HTML through `NSAttributedString(html:)` (macOS's own,
/// reliable HTML parser — safer than hand-rolling one) and paginates it
/// into a real multi-page PDF via `CTFramesetter`, the standard CoreText
/// technique for flowing an attributed string across pages.
enum DocumentationExporter {
    enum Format { case markdown, html, pdf }

    static func presentSavePanelAndExport(document: DiagramDocument, format: Format, window: NSWindow?) {
        let panel = NSSavePanel()
        let baseName = document.model.title.isEmpty ? "Documentation" : document.model.title
        switch format {
        case .markdown:
            panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
            panel.nameFieldStringValue = "\(baseName).md"
        case .html:
            panel.allowedContentTypes = [.html]
            panel.nameFieldStringValue = "\(baseName).html"
        case .pdf:
            panel.allowedContentTypes = [.pdf]
            panel.nameFieldStringValue = "\(baseName).pdf"
        }

        let pages = document.model.pageOrder.compactMap { document.model.pages[$0] }
        let adrs = document.adrs
        let handleResponse: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try export(title: document.model.title, pages: pages, adrs: adrs, format: format, to: url)
            } catch {
                presentError(error, in: window)
            }
        }
        if let window {
            panel.beginSheetModal(for: window, completionHandler: handleResponse)
        } else {
            handleResponse(panel.runModal())
        }
    }

    private static func export(title: String, pages: [DiagramPage], adrs: [ArchitectureDecisionRecord], format: Format, to url: URL) throws {
        switch format {
        case .markdown:
            let markdown = DocumentationGenerator.markdown(title: title, pages: pages, adrs: adrs)
            try markdown.write(to: url, atomically: true, encoding: .utf8)
        case .html:
            let html = DocumentationGenerator.html(title: title, pages: pages, adrs: adrs)
            try html.write(to: url, atomically: true, encoding: .utf8)
        case .pdf:
            let html = DocumentationGenerator.html(title: title, pages: pages, adrs: adrs)
            try writePDF(html: html, to: url)
        }
    }

    private static func writePDF(html: String, to url: URL) throws {
        guard let data = html.data(using: .utf8) else { throw ExportError.encodingFailed }
        let attributed = try NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue],
            documentAttributes: nil
        )

        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter, 72 dpi
        let margin: CGFloat = 54
        let textRect = pageRect.insetBy(dx: margin, dy: margin)

        guard let consumer = CGDataConsumer(url: url as CFURL) else { throw ExportError.encodingFailed }
        var mediaBox = pageRect
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { throw ExportError.encodingFailed }

        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        var currentIndex = 0
        let totalLength = attributed.length
        let path = CGPath(rect: textRect, transform: nil)

        repeat {
            context.beginPDFPage(nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: currentIndex, length: 0), path, nil)
            CTFrameDraw(frame, context)
            let visibleRange = CTFrameGetVisibleStringRange(frame)
            context.endPDFPage()

            if visibleRange.length <= 0 { break }
            currentIndex += visibleRange.length
        } while currentIndex < totalLength

        context.closePDF()
    }

    private enum ExportError: LocalizedError {
        case encodingFailed
        var errorDescription: String? { "Couldn't generate the document." }
    }

    private static func presentError(_ error: Error, in window: NSWindow?) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Export Failed"
        alert.informativeText = error.localizedDescription
        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}
