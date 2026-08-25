import SwiftUI
import AppKit

@main
struct ArqidoDiagramApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Document lifecycle is driven by NSDocumentController (see
        // AppDelegate + DiagramDocument), not SwiftUI's DocumentGroup —
        // NSDocument gives the autosave-in-place, atomic package I/O, and
        // crash-recovery hooks the spec calls for by name, while SwiftUI
        // still owns all UI content via NSHostingView (DiagramDocumentWindowController).
        // This Settings scene only keeps the App protocol satisfied and
        // carries the shared menu-bar commands.
        Settings {
            EmptyView()
        }
        .commands {
            AppCommands()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        if NSDocumentController.shared.documents.isEmpty {
            NSDocumentController.shared.newDocument(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
