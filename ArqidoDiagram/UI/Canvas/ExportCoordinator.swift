import AppKit
import UniformTypeIdentifiers
import DiagramModel
import DiagramRendering
import DiagramExport

/// Presents the save panel and runs the actual PNG/PDF/SVG generation —
/// kept out of `DiagramRendering` (see `DiagramCanvasView`'s Export section)
/// so that module never depends on `DiagramExport`/`AppKit`'s
/// `NSSavePanel`.
enum ExportCoordinator {
    static func presentSavePanelAndExport(page: DiagramPage, format: DiagramCanvasView.ExportFormat, window: NSWindow?) {
        let panel = NSSavePanel()
        let baseName = page.name.isEmpty ? "Untitled" : page.name
        switch format {
        case .png:
            panel.allowedContentTypes = [.png]
            panel.nameFieldStringValue = "\(baseName).png"
        case .pdf:
            panel.allowedContentTypes = [.pdf]
            panel.nameFieldStringValue = "\(baseName).pdf"
        case .svg:
            panel.allowedContentTypes = [UTType(filenameExtension: "svg") ?? .data]
            panel.nameFieldStringValue = "\(baseName).svg"
        }

        let handleResponse: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            Task {
                do {
                    switch format {
                    case .png: try await PNGExportAdapter.write(page, to: url)
                    case .pdf: try await PDFExportAdapter.write(page, to: url)
                    case .svg: try await SVGExportAdapter.write(page, to: url)
                    }
                } catch {
                    await MainActor.run { presentError(error, in: window) }
                }
            }
        }

        if let window {
            panel.beginSheetModal(for: window, completionHandler: handleResponse)
        } else {
            handleResponse(panel.runModal())
        }
    }

    static func copyAsSVG(page: DiagramPage) {
        let svg = SVGExportAdapter.string(for: page)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(svg, forType: .string)
        if let svgType = UTType(filenameExtension: "svg") {
            pasteboard.setString(svg, forType: NSPasteboard.PasteboardType(svgType.identifier))
        }
    }

    @MainActor
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
