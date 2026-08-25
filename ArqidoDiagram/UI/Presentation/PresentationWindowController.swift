import AppKit
import SwiftUI
import DiagramModel
import DiagramRendering

/// Spec §PRESENTATION MODE: "Full screen". A dedicated, screen-covering
/// borderless `NSWindow` rather than real macOS Fullscreen
/// (`NSWindow.toggleFullScreen`) — that API's only built-in exit is the
/// green button / Ctrl+Cmd+F, which doesn't fit a Keynote-style
/// Esc-to-exit, arrow-keys-to-advance playback surface. `PresentationCanvasView`
/// (read-only, no editing) does the actual drawing; this controller only
/// owns the window and forwards keyboard/HUD input into a
/// `PresentationController` (the pure, testable navigation/zoom/focus state).
final class PresentationWindowController: NSWindowController {
    /// Keeps the controller (and its window) alive for as long as
    /// presenting is happening — `PresentationContainerView.onExit` clears
    /// this, which is what actually releases the window.
    private static var active: PresentationWindowController?

    static func present(document: DiagramDocument, startIndex: Int) {
        guard !document.frames.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "No Frames Yet"
            alert.informativeText = "Capture at least one frame in the Presentation Frames panel before playing."
            alert.runModal()
            return
        }
        let controller = PresentationWindowController(frames: document.frames, pagesByID: document.model.pages, startIndex: startIndex)
        active = controller
        controller.showWindow(nil)
    }

    private convenience init(frames: [PresentationFrame], pagesByID: [PageID: DiagramPage], startIndex: Int) {
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let window = NSWindow(contentRect: screenFrame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = .floating
        window.isOpaque = true
        window.backgroundColor = .black
        window.hasShadow = false
        window.collectionBehavior = [.fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = false

        let container = PresentationContainerView(frame: NSRect(origin: .zero, size: screenFrame.size))
        container.configure(pagesByID: pagesByID, frames: frames, startIndex: startIndex)
        window.contentView = container

        self.init(window: window)
        container.onExit = { [weak self] in
            self?.close()
            PresentationWindowController.active = nil
        }
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        NSCursor.hide()
        if let container = window?.contentView {
            window?.makeFirstResponder(container)
        }
    }

    override func close() {
        NSCursor.unhide()
        super.close()
    }
}

/// The `NSView` that actually owns the presentation surface: a
/// `PresentationCanvasView` filling the window plus a translucent bottom
/// HUD (`PresentationHUDView`, hosted via `NSHostingView`) for Previous/
/// Next/Focus/Exit — keyboard shortcuts (arrow keys/space, F, +/-/0, Esc)
/// do the same things for anyone who'd rather not reach for the HUD.
final class PresentationContainerView: NSView {
    private let canvasView: PresentationCanvasView
    private let hudState = PresentationHUDState()
    private var hud: NSHostingView<PresentationHUDView>?
    private var controller = PresentationController(frames: [])
    private var pagesByID: [PageID: DiagramPage] = [:]

    var onExit: (() -> Void)?

    override init(frame frameRect: NSRect) {
        canvasView = PresentationCanvasView(frame: frameRect)
        super.init(frame: frameRect)
        wantsLayer = true
        canvasView.autoresizingMask = [.width, .height]
        addSubview(canvasView)
        installHUD()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(pagesByID: [PageID: DiagramPage], frames: [PresentationFrame], startIndex: Int) {
        self.pagesByID = pagesByID
        controller = PresentationController(frames: frames, startIndex: startIndex)
        refresh()
    }

    private func installHUD() {
        let hudView = PresentationHUDView(
            state: hudState,
            onPrevious: { [weak self] in self?.goPrevious() },
            onNext: { [weak self] in self?.goNext() },
            onToggleFocus: { [weak self] in self?.toggleFocus() },
            onZoomOut: { [weak self] in self?.zoomOut() },
            onZoomIn: { [weak self] in self?.zoomIn() },
            onExit: { [weak self] in self?.exitPresentation() }
        )
        let hosting = NSHostingView(rootView: hudView)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: trailingAnchor),
            hosting.bottomAnchor.constraint(equalTo: bottomAnchor),
            hosting.heightAnchor.constraint(equalToConstant: 56)
        ])
        hud = hosting
    }

    override func layout() {
        super.layout()
        refreshViewport()
    }

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.specialKey {
        case .some(.rightArrow):
            goNext()
        case .some(.leftArrow):
            goPrevious()
        default:
            switch event.charactersIgnoringModifiers {
            case " ": goNext()
            case "f", "F": toggleFocus()
            case "+", "=": zoomIn()
            case "-", "_": zoomOut()
            case "0": resetZoom()
            default: super.keyDown(with: event)
            }
        }
    }

    /// Standard AppKit action bound to Esc when this view is first
    /// responder — the same mechanism `DiagramCanvasView`'s inline text
    /// editing uses to let Esc cancel without a custom key-code check.
    override func cancelOperation(_ sender: Any?) {
        exitPresentation()
    }

    private func goNext() { controller.next(); refresh() }
    private func goPrevious() { controller.previous(); refresh() }
    private func toggleFocus() { controller.toggleFocus(); refresh() }
    private func zoomIn() { controller.zoomIn(); refreshViewport() }
    private func zoomOut() { controller.zoomOut(); refreshViewport() }
    private func resetZoom() { controller.resetZoom(); refreshViewport() }
    private func exitPresentation() { onExit?() }

    private func refresh() {
        canvasView.page = controller.currentFrame.flatMap { pagesByID[$0.pageID] }
        canvasView.focusNodeIDs = controller.activeFocusNodeIDs
        refreshViewport()

        hudState.frameName = controller.currentFrame?.name ?? ""
        hudState.positionLabel = controller.frames.isEmpty ? "" : "\(controller.currentIndex + 1) / \(controller.frames.count)"
        hudState.hasPrevious = controller.hasPrevious
        hudState.hasNext = controller.hasNext
        hudState.isFocusOn = controller.isFocusModeOn
    }

    private func refreshViewport() {
        guard let viewport = controller.viewport(for: canvasView.bounds.size) else { return }
        canvasView.viewport = viewport
    }
}
