import AppKit
import SwiftUI

final class DiagramDocumentWindowController: NSWindowController {
    convenience init(document: DiagramDocument) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.setFrameAutosaveName("ArqidoDiagramMainWindow")
        window.title = document.displayName
        window.contentView = NSHostingView(rootView: ContentView(document: document))

        self.init(window: window)
    }
}
