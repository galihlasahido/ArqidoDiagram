import SwiftUI

/// TODO(Phase 1, build-order step 4): replace this placeholder with the real
/// `NSViewRepresentable` bridge to `DiagramRendering`'s `NSView`-backed Core
/// Graphics canvas — never SwiftUI `Canvas`, per the Visual/UI Style
/// requirements. Shown as an explicit "not available yet" state rather than
/// fabricated sample content.
struct CanvasHostView: View {
    var body: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)
            VStack(spacing: 8) {
                Image(systemName: "square.on.square.dashed")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                Text("Canvas not available yet")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
