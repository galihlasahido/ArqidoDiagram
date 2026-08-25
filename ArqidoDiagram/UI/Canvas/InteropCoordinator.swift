import AppKit
import UniformTypeIdentifiers
import DiagramModel
import DiagramRendering
import DiagramLayout
import DiagramInterop

/// The text-format counterpart of `ExportCoordinator` (Mermaid/PlantUML/
/// Graphviz DOT/Architecture-as-Code YAML/SQL export) plus File > Import…
/// (spec §22: SQL/OpenAPI/Docker Compose/Kubernetes/Terraform/Architecture
/// YAML). Kept out of `DiagramRendering` for the same reason
/// `ExportCoordinator` is: that module has no business depending on
/// `DiagramInterop`/`AppKit`'s file panels.
enum InteropCoordinator {
    static func exportText(_ page: DiagramPage, format: DiagramCanvasView.TextExportFormat, architectureName: String) -> String {
        switch format {
        case .mermaid: return MermaidExporter.export(page)
        case .plantUML: return PlantUMLExporter.export(page)
        case .graphvizDOT: return GraphvizExporter.export(page, name: architectureName)
        case .architectureYAML: return ArchitectureYAMLExporter.export(page, architectureName: architectureName)
        case .sql: return SQLExporter.export(page)
        }
    }

    static func presentSavePanelAndExportText(page: DiagramPage, format: DiagramCanvasView.TextExportFormat, architectureName: String, window: NSWindow?) {
        let panel = NSSavePanel()
        let baseName = page.name.isEmpty ? "Untitled" : page.name
        let (extension_, contentType): (String, UTType) = {
            switch format {
            case .mermaid: return ("mmd", UTType(filenameExtension: "mmd") ?? .plainText)
            case .plantUML: return ("puml", UTType(filenameExtension: "puml") ?? .plainText)
            case .graphvizDOT: return ("dot", UTType(filenameExtension: "dot") ?? .plainText)
            case .architectureYAML: return ("yaml", UTType(filenameExtension: "yaml") ?? .plainText)
            case .sql: return ("sql", UTType(filenameExtension: "sql") ?? .plainText)
            }
        }()
        panel.allowedContentTypes = [contentType]
        panel.nameFieldStringValue = "\(baseName).\(extension_)"

        let text = exportText(page, format: format, architectureName: architectureName)
        let handleResponse: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                presentError(error, title: "Export Failed", in: window)
            }
        }
        if let window {
            panel.beginSheetModal(for: window, completionHandler: handleResponse)
        } else {
            handleResponse(panel.runModal())
        }
    }

    static func copyText(_ page: DiagramPage, format: DiagramCanvasView.TextExportFormat, architectureName: String) {
        let text = exportText(page, format: format, architectureName: architectureName)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    // MARK: - Import

    static func presentOpenPanelAndImport(canvasView: DiagramCanvasView?, window: NSWindow?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        // Deliberately permissive — .sql/.tf/.yaml/.yml/.json all need to
        // be selectable, and `detectFormatAndParse` (not the file's
        // UTType) is what actually decides the format.
        panel.allowedContentTypes = []
        panel.message = "Import a SQL schema, OpenAPI document, Docker Compose file, Kubernetes manifest, Terraform file, or Architecture-as-Code YAML."

        let handleResponse: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                guard let spec = detectFormatAndParse(text: text, fileExtension: url.pathExtension.lowercased()) else {
                    presentError(ImportError.unrecognizedFormat, title: "Import Failed", in: window)
                    return
                }
                let (nodes, edges) = DiagramSpecMaterializer.materialize(spec)
                canvasView?.insertGeneratedNodes(nodes, edges: edges)
            } catch {
                presentError(error, title: "Import Failed", in: window)
            }
        }
        if let window {
            panel.beginSheetModal(for: window, completionHandler: handleResponse)
        } else {
            handleResponse(panel.runModal())
        }
    }

    private enum ImportError: LocalizedError {
        case unrecognizedFormat
        var errorDescription: String? {
            "Couldn't recognize this file's format. Supported: SQL, OpenAPI, Docker Compose, Kubernetes YAML, Terraform, Architecture-as-Code YAML."
        }
    }

    /// Extension is the strongest signal when present (`.sql`/`.tf` are
    /// unambiguous); otherwise falls back to content sniffing for the
    /// YAML-based formats, which all commonly ship as plain `.yaml`/`.yml`.
    private static func detectFormatAndParse(text: String, fileExtension: String) -> GeneratedDiagramSpec? {
        switch fileExtension {
        case "sql": return SQLSchemaImporter.parse(text)
        case "tf", "tfvars": return TerraformImporter.parse(text)
        default: break
        }

        if text.contains("architecture:") && text.contains("services:") {
            return ArchitectureYAMLImporter.parse(text).spec
        }
        if text.contains("openapi:") || text.contains("swagger:") {
            return OpenAPIImporter.parse(text)
        }
        if text.contains("apiVersion:") && text.contains("kind:") {
            return KubernetesImporter.parse(text)
        }
        if text.contains("services:") {
            return DockerComposeImporter.parse(text)
        }
        if text.range(of: #"(?i)CREATE\s+TABLE"#, options: .regularExpression) != nil {
            return SQLSchemaImporter.parse(text)
        }
        if text.range(of: #"resource\s+""#, options: .regularExpression) != nil {
            return TerraformImporter.parse(text)
        }
        return nil
    }

    private static func presentError(_ error: Error, title: String, in window: NSWindow?) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}
