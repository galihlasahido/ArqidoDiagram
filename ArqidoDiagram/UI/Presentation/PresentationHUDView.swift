import SwiftUI

/// Drives `PresentationHUDView` from `PresentationContainerView` (AppKit) —
/// a plain `ObservableObject` rather than threading raw values through
/// `NSHostingView.rootView` reassignment on every navigation.
final class PresentationHUDState: ObservableObject {
    @Published var frameName = ""
    @Published var positionLabel = ""
    @Published var hasPrevious = false
    @Published var hasNext = false
    @Published var isFocusOn = false
}

/// The translucent bottom bar shown while presenting: Previous/Next (spec's
/// "Previous"/"Next"), a Focus toggle (spec's "Focus"), zoom in/out (spec's
/// "Zoom"), and Exit — all of which also have keyboard equivalents (see
/// `PresentationContainerView.keyDown`) for anyone who'd rather not move
/// the mouse during a presentation.
struct PresentationHUDView: View {
    @ObservedObject var state: PresentationHUDState
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToggleFocus: () -> Void
    let onZoomOut: () -> Void
    let onZoomIn: () -> Void
    let onExit: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onExit) {
                Image(systemName: "xmark")
            }
            .help("Exit Presentation (Esc)")

            Divider().frame(height: 20)

            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
            }
            .disabled(!state.hasPrevious)
            .help("Previous (\u{2190})")

            VStack(spacing: 1) {
                Text(state.frameName).font(.callout.weight(.semibold))
                Text(state.positionLabel).font(.caption).foregroundStyle(.secondary)
            }
            .frame(minWidth: 140)

            Button(action: onNext) {
                Image(systemName: "chevron.right")
            }
            .disabled(!state.hasNext)
            .help("Next (\u{2192} / Space)")

            Divider().frame(height: 20)

            Button(action: onToggleFocus) {
                Image(systemName: state.isFocusOn ? "scope" : "circle.dashed")
            }
            .help("Toggle Focus (F)")

            Button(action: onZoomOut) {
                Image(systemName: "minus.magnifyingglass")
            }
            .help("Zoom Out (-)")

            Button(action: onZoomIn) {
                Image(systemName: "plus.magnifyingglass")
            }
            .help("Zoom In (+)")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.6))
    }
}
