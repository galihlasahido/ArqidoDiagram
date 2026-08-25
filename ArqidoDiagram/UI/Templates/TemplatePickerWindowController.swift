import AppKit
import SwiftUI
import DiagramModel

/// Owns its own plain `NSWindow` (not a sheet) so it behaves like "New
/// Project" pickers generally do — a standalone chooser, not attached to
/// any particular document window. `AppCommands` has no per-window state to
/// hand it (same reasoning as `.toggleSearch`/`.toggleValidation`), so this
/// is triggered as a direct static call rather than a notification.
final class TemplatePickerWindowController: NSWindowController {
    /// Held statically so the window (and its controller) isn't deallocated
    /// the instant `show()` returns — there is deliberately only ever one
    /// picker open at a time.
    private static var current: TemplatePickerWindowController?

    static func show() {
        if let current {
            current.window?.makeKeyAndOrderFront(nil)
            return
        }
        let controller = TemplatePickerWindowController()
        current = controller
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "New from Template"
        window.center()
        self.init(window: window)

        window.contentView = NSHostingView(rootView: TemplatePickerView(
            onSelect: { [weak self] template in
                self?.createDocument(from: template)
                self?.close()
            },
            onCancel: { [weak self] in
                self?.close()
            }
        ))
    }

    override func close() {
        super.close()
        Self.current = nil
    }

    private func createDocument(from template: DiagramTemplate) {
        let document = DiagramDocument(template: template)
        NSDocumentController.shared.addDocument(document)
        document.makeWindowControllers()
        document.showWindows()
    }
}
