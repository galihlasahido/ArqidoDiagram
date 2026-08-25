import SwiftUI
import DiagramModel
import DiagramRendering

/// Spec §PRESENTATION MODE: "Frames". Lists the document's saved frames in
/// slide-show order; "Capture Current View" reads the live canvas's
/// viewport (via `inspectorBridge.canvasView`, the same read/write path
/// Inspector uses) to save exactly what's on screen right now as a new
/// frame, the same "what you see is what gets saved" contract
/// `saveVersionSnapshot`/`saveSelectionAsComponent` follow elsewhere.
struct PresentationFramePanelView: View {
    @ObservedObject var document: DiagramDocument
    @ObservedObject var frameModel: PresentationFrameModel
    @ObservedObject var inspectorBridge: InspectorBridge
    @Binding var activePageID: PageID?
    @ObservedObject var selection: SelectionModel

    @State private var renamingFrameID: FrameID?
    @State private var renameText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if document.frames.isEmpty {
                Text("No frames yet. Frame the view you want on the canvas, then Capture Current View to save it as a slide.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                list
            }
            Divider()
            footer
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor)))
        .shadow(radius: 8)
        .frame(width: 360)
    }

    private var header: some View {
        HStack {
            Image(systemName: "play.rectangle")
                .foregroundStyle(.secondary)
            Text("Presentation Frames")
                .font(.callout.weight(.semibold))
            Spacer()
            Text("\(document.frames.count)")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Button {
                frameModel.isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(8)
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(document.frames.enumerated()), id: \.element.id) { index, frame in
                    row(frame, index: index)
                    Divider()
                }
            }
        }
        .frame(maxHeight: 320)
    }

    private func row(_ frame: PresentationFrame, index: Int) -> some View {
        HStack {
            Text("\(index + 1)")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .trailing)

            if renamingFrameID == frame.id {
                TextField("Frame name", text: $renameText, onCommit: { commitRename(frame) })
                    .textFieldStyle(.roundedBorder)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(frame.name).font(.callout)
                    Text(document.model.pages[frame.pageID]?.name ?? "Deleted page")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                startPresenting(from: index)
            } label: {
                Image(systemName: "play.fill")
            }
            .buttonStyle(.plain)
            .help("Play from here")

            Menu {
                Button("Rename…") { beginRename(frame) }
                Button("Update to Current View") { updateFrameToCurrentView(frame) }
                Button("Move Up") { document.moveFrame(from: index, to: index - 1) }
                    .disabled(index == 0)
                Button("Move Down") { document.moveFrame(from: index, to: index + 2) }
                    .disabled(index == document.frames.count - 1)
                Divider()
                Button("Delete", role: .destructive) { document.deleteFrame(id: frame.id) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var footer: some View {
        HStack {
            Button("Capture Current View") { captureCurrentView() }
                .disabled(inspectorBridge.canvasView == nil)
            Spacer()
            Button("Play Presentation") { startPresenting(from: 0) }
                .disabled(document.frames.isEmpty)
                .keyboardShortcut(.defaultAction)
        }
        .padding(8)
    }

    private func captureCurrentView() {
        guard let canvasView = inspectorBridge.canvasView, let pageID = activePageID else { return }
        let contentRect = canvasView.viewport.viewToContent(rect: canvasView.bounds)
        document.addFrame(
            pageID: pageID,
            name: "Frame \(document.frames.count + 1)",
            rect: Rect2D(contentRect),
            focusNodeIDs: Array(selection.selectedNodeIDs)
        )
    }

    private func updateFrameToCurrentView(_ frame: PresentationFrame) {
        guard let canvasView = inspectorBridge.canvasView else { return }
        var updated = frame
        updated.rect = Rect2D(canvasView.viewport.viewToContent(rect: canvasView.bounds))
        updated.focusNodeIDs = Array(selection.selectedNodeIDs)
        document.updateFrame(updated)
    }

    private func beginRename(_ frame: PresentationFrame) {
        renamingFrameID = frame.id
        renameText = frame.name
    }

    private func commitRename(_ frame: PresentationFrame) {
        var updated = frame
        updated.name = renameText.isEmpty ? frame.name : renameText
        document.updateFrame(updated)
        renamingFrameID = nil
    }

    private func startPresenting(from index: Int) {
        PresentationWindowController.present(document: document, startIndex: index)
    }
}
