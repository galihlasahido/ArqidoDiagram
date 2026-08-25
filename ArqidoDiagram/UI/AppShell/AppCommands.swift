import SwiftUI
import AppKit

/// Menu bar / keyboard shortcut wiring. `Settings {}` (see
/// `ArqidoDiagramApp`) doesn't auto-generate a File menu the way
/// `DocumentGroup` would, so New/Open/Save/Save As are wired explicitly here
/// via `NSDocumentController` and the standard `NSDocument` responder-chain
/// actions (`saveDocument:`/`saveDocumentAs:`) — the same selectors a
/// storyboard-based document app's File menu would send.
///
/// Undo/Redo intentionally use SwiftUI's default `.undoRedo` command group
/// (not replaced here): with no `CommandStack`/registered commands yet
/// (lands at build-order step 8), they correctly show disabled, matching
/// standard Cocoa behavior for "nothing to undo" rather than being wired to
/// do nothing silently.
struct AppCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New") {
                NSDocumentController.shared.newDocument(nil)
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("Open…") {
                NSDocumentController.shared.openDocument(nil)
            }
            .keyboardShortcut("o", modifiers: .command)
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                NSApp.sendAction(Selector(("saveDocument:")), to: nil, from: nil)
            }
            .keyboardShortcut("s", modifiers: .command)

            Button("Save As…") {
                NSApp.sendAction(Selector(("saveDocumentAs:")), to: nil, from: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
        }

        CommandGroup(after: .toolbar) {
            // Real, visibly-disabled affordance rather than a hidden or
            // faked feature — ⌘K is in the spec's minimum shortcut list, but
            // AIProvider (DiagramFoundation) has no implementation yet.
            Button("AI Command Bar…") {}
                .keyboardShortcut("k", modifiers: .command)
                .disabled(true)
                .help("AI features are not available yet.")
        }
    }
}
