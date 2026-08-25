import SwiftUI
import AppKit

/// Menu bar / keyboard shortcut wiring. `Settings {}` (see
/// `ArqidoDiagramApp`) doesn't auto-generate a File/Edit menu the way
/// `DocumentGroup` would, so every item here is wired explicitly through the
/// standard AppKit responder chain — `NSApp.sendAction(_:to: nil, from:)`
/// sends to whatever object is first responder (the key document window's
/// `DiagramCanvasView`), the same mechanism a storyboard-based app's menu
/// bar would use. Undo/Redo route through `DiagramCanvasView.undoManager`
/// (which overrides `NSResponder.undoManager` to expose the document's real
/// `UndoManager`), so the standard `undo:`/`redo:` actions — and their
/// automatic "Undo Move"/"Redo Resize" labeling via `setActionName` — work
/// without any custom logic here.
struct AppCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New") {
                NSDocumentController.shared.newDocument(nil)
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("New from Template…") {
                TemplatePickerWindowController.show()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

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

        CommandGroup(after: .saveItem) {
            Menu("Export") {
                Button("PNG…") { NSApp.sendAction(Selector(("exportPNG:")), to: nil, from: nil) }
                Button("PDF…") { NSApp.sendAction(Selector(("exportPDF:")), to: nil, from: nil) }
                Button("SVG…") { NSApp.sendAction(Selector(("exportSVG:")), to: nil, from: nil) }
            }
        }

        CommandGroup(replacing: .undoRedo) {
            Button("Undo") {
                NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
            }
            .keyboardShortcut("z", modifiers: .command)

            Button("Redo") {
                NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .pasteboard) {
            Button("Cut") {
                NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("x", modifiers: .command)

            Button("Copy") {
                NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("c", modifiers: .command)

            Button("Paste") {
                NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("v", modifiers: .command)

            Button("Copy as SVG") {
                NSApp.sendAction(Selector(("copyAsSVG:")), to: nil, from: nil)
            }
            .keyboardShortcut("c", modifiers: [.command, .option])

            Divider()

            Button("Duplicate") {
                NSApp.sendAction(Selector(("duplicate:")), to: nil, from: nil)
            }
            .keyboardShortcut("d", modifiers: .command)

            Button("Delete") {
                NSApp.sendAction(Selector(("delete:")), to: nil, from: nil)
            }
            .keyboardShortcut(.delete, modifiers: [])

            Divider()

            Button("Select All") {
                NSApp.sendAction(#selector(NSResponder.selectAll(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("a", modifiers: .command)
        }

        CommandGroup(after: .textEditing) {
            Button("Find…") {
                NotificationCenter.default.post(name: .toggleSearch, object: nil)
            }
            .keyboardShortcut("f", modifiers: .command)
        }

        CommandMenu("Validation") {
            Button("Show Validation") {
                NotificationCenter.default.post(name: .toggleValidation, object: nil)
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])
        }

        CommandMenu("Arrange") {
            Button("Bring Forward") {
                NSApp.sendAction(Selector(("bringForward:")), to: nil, from: nil)
            }
            .keyboardShortcut("]", modifiers: .command)

            Button("Send Backward") {
                NSApp.sendAction(Selector(("sendBackward:")), to: nil, from: nil)
            }
            .keyboardShortcut("[", modifiers: .command)

            Divider()

            Button("Group") {
                NSApp.sendAction(Selector(("groupSelection:")), to: nil, from: nil)
            }
            .keyboardShortcut("g", modifiers: .command)

            Button("Ungroup") {
                NSApp.sendAction(Selector(("ungroupSelection:")), to: nil, from: nil)
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])

            Button("Save Selection as Component…") {
                NSApp.sendAction(Selector(("saveSelectionAsComponent:")), to: nil, from: nil)
            }

            Divider()

            Button("Lock") { NSApp.sendAction(Selector(("toggleLock:")), to: nil, from: nil) }
                .keyboardShortcut("l", modifiers: .command)
            Button("Hide") { NSApp.sendAction(Selector(("toggleHidden:")), to: nil, from: nil) }
                .keyboardShortcut("h", modifiers: [.command, .shift])

            Divider()

            Button("Align Left") { NSApp.sendAction(Selector(("alignLeft:")), to: nil, from: nil) }
            Button("Align Right") { NSApp.sendAction(Selector(("alignRight:")), to: nil, from: nil) }
            Button("Align Center") { NSApp.sendAction(Selector(("alignCenterHorizontally:")), to: nil, from: nil) }
            Button("Align Top") { NSApp.sendAction(Selector(("alignTop:")), to: nil, from: nil) }
            Button("Align Bottom") { NSApp.sendAction(Selector(("alignBottom:")), to: nil, from: nil) }
            Button("Align Middle") { NSApp.sendAction(Selector(("alignMiddle:")), to: nil, from: nil) }

            Divider()

            Button("Distribute Horizontally") { NSApp.sendAction(Selector(("distributeHorizontally:")), to: nil, from: nil) }
            Button("Distribute Vertically") { NSApp.sendAction(Selector(("distributeVertically:")), to: nil, from: nil) }
        }

        CommandMenu("Layout") {
            Button("Hierarchical") { NSApp.sendAction(Selector(("applyHierarchicalLayout:")), to: nil, from: nil) }
            Button("Tree") { NSApp.sendAction(Selector(("applyTreeLayout:")), to: nil, from: nil) }
            Button("Grid") { NSApp.sendAction(Selector(("applyGridLayout:")), to: nil, from: nil) }
            Button("Force-Directed") { NSApp.sendAction(Selector(("applyForceDirectedLayout:")), to: nil, from: nil) }
            Button("Circular") { NSApp.sendAction(Selector(("applyCircularLayout:")), to: nil, from: nil) }
            Button("Orthogonal") { NSApp.sendAction(Selector(("applyOrthogonalLayout:")), to: nil, from: nil) }
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
