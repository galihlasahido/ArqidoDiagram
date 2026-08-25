import Foundation

/// Spec §PRESENTATION MODE: "Frames, Full screen, Previous, Next, Zoom,
/// Focus". A frame is a saved, named viewport region on one page — the
/// presentation equivalent of a slide. Document order (an array on
/// `DiagramDocumentModel`, see `DiagramDocument.frames`) is the frame's
/// slide-show order; there's no separate `order` field for it to drift out
/// of sync with.
public struct PresentationFrame: Codable, Identifiable, Equatable, Sendable {
    public let id: FrameID
    public var pageID: PageID
    public var name: String
    /// The content-space region this frame fits the viewport to when
    /// presented — captured from the live canvas viewport at creation time
    /// (see `DiagramCanvasView.viewport`), not tied to any node's own frame.
    public var rect: Rect2D
    /// Spec's "Focus": the nodes to keep at full opacity while presenting
    /// this frame; every other node on the page dims. Empty means no
    /// dimming (the whole frame reads normally).
    public var focusNodeIDs: [NodeID]
    public var createdAt: Date

    public init(
        id: FrameID = FrameID(),
        pageID: PageID,
        name: String,
        rect: Rect2D,
        focusNodeIDs: [NodeID] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.pageID = pageID
        self.name = name
        self.rect = rect
        self.focusNodeIDs = focusNodeIDs
        self.createdAt = createdAt
    }
}
