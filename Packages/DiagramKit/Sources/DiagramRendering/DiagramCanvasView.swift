import AppKit
import DiagramModel
import DiagramCommands

/// The infinite diagram canvas: a real `NSView` drawing via Core Graphics,
/// never SwiftUI `Canvas` — per the Visual/UI Style requirements. Draws only
/// what the spatial index reports as intersecting the dirty rect; pan/zoom
/// changes are the one case that legitimately redraws the full view (the
/// transform itself changed, so there's no smaller dirty rect to compute).
///
/// Click-to-select, marquee, move/resize/rotate drag, and the standard
/// edit actions (delete/duplicate/copy/paste/z-order) live directly on this
/// view rather than behind a `DiagramInteraction` "tool" abstraction: they
/// share one hit-testing/selection core tightly enough that splitting them
/// into dispatched tool objects would mostly move code around, not clarify
/// it, at Phase 1's feature set. Revisit once draw-connector (step 13)
/// introduces a genuinely different interaction mode.
///
/// TODO: edges aren't individually selectable/deletable yet (no edge
/// hit-testing) — a reasonable Phase 1 scope cut, not an oversight; edges
/// still fully support creation, automatic re-routing on node move, and
/// undo (their `AddEdgesCommand`/`RemoveEdgesCommand` already exist).
public final class DiagramCanvasView: NSView {
    public var viewport = CanvasViewport() {
        didSet {
            guard viewport != oldValue else { return }
            needsDisplay = true
            onViewportChange?(viewport)
        }
    }

    /// Notifies the SwiftUI bridge of viewport changes (zoom%, for the
    /// status bar) without making this view depend on SwiftUI/Combine.
    public var onViewportChange: ((CanvasViewport) -> Void)?

    /// Notifies the SwiftUI bridge when selection changes *from user
    /// interaction on this view* (click, marquee) — not called from
    /// `applyExternalSelection`, since that call already originated on the
    /// SwiftUI side and echoing it back would just be a no-op round trip.
    public var onSelectionChange: ((Set<NodeID>) -> Void)?

    /// Fired once per *committed* mutation (a completed drag, delete,
    /// add-shape, ...) — never per intermediate live-preview frame. The app
    /// target uses this to pull `currentPageSnapshot(...)` and write it
    /// into `DiagramDocument.model`, which is what persistence actually
    /// reads; without this, canvas edits would live only in `scene` and
    /// never make it into a saved `.diagram` file.
    public var onSceneChanged: (() -> Void)?

    private let scene: SceneStore
    private let spatialIndex = SpatialGrid()
    private lazy var commandStack = CommandStack(scene: scene)

    /// Set by the app target to the document's `NSDocument.undoManager`.
    /// Named distinctly from `NSResponder.undoManager` (get-only in
    /// AppKit's public interface — a subclass can't add a setter to it)
    /// for the external wire-up; `undoManager` below overrides the getter
    /// to expose it, which is what makes the standard Edit menu Undo/Redo
    /// items (and their "Undo Move"/"Redo Resize" labeling via
    /// `setActionName`) work through the normal responder chain.
    public var documentUndoManager: UndoManager? {
        didSet { commandStack.undoManager = documentUndoManager }
    }

    public override var undoManager: UndoManager? { documentUndoManager }

    public private(set) var selection: Set<NodeID> = []

    public override init(frame frameRect: NSRect) {
        scene = SceneStore(page: DiagramPage(name: "", order: 0))
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        scene = SceneStore(page: DiagramPage(name: "", order: 0))
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    /// Top-left origin, y increasing downward — the standard 2D
    /// diagram-editor convention `DiagramModel.Point2D` assumes.
    public override var isFlipped: Bool { true }

    public override var acceptsFirstResponder: Bool { true }

    // MARK: - Content

    private var hasPerformedInitialFit = false

    /// Fits on the first resize where `bounds` has actually settled to a
    /// plausible real size — calling `fitToScreen()` right after
    /// `makeNSView`, or on an early/intermediate placeholder frame before
    /// `NavigationSplitView`'s column negotiation settles, would compute a
    /// scale from a transient, too-small frame. 120pt is comfortably above
    /// any such placeholder frame but below any real canvas pane size.
    ///
    /// `setFrameSize(_:)`, not `layout()`, is the hook: SwiftUI's
    /// `NSViewRepresentable` bridge resizes this view directly (it doesn't
    /// necessarily drive AppKit's own Auto Layout `layout()` pass), so
    /// `setFrameSize` is the one override guaranteed to fire whenever this
    /// view's actual size changes, regardless of hosting mechanism.
    private static let minimumPlausibleDimension: CGFloat = 120

    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        performInitialFitIfNeeded()
    }

    private func performInitialFitIfNeeded() {
        guard !hasPerformedInitialFit,
              bounds.width > Self.minimumPlausibleDimension,
              bounds.height > Self.minimumPlausibleDimension else { return }
        hasPerformedInitialFit = true
        fitToScreen()
    }

    public func loadPage(_ page: DiagramPage) {
        scene.load(from: page)
        rebuildSpatialIndex()
        let prunedSelection = selection.intersection(scene.nodes.keys)
        if prunedSelection != selection {
            updateSelectionFromInteraction(prunedSelection)
        }
        needsDisplay = true
    }

    private func rebuildSpatialIndex() {
        spatialIndex.removeAll()
        for node in scene.nodes.values {
            spatialIndex.insert(node.id, bounds: node.frame)
        }
    }

    public var nodeCount: Int { scene.nodes.count }

    public func fitToScreen(padding: CGFloat = 40) {
        viewport = CanvasViewport.fitting(contentBounds: contentBounds(), viewSize: bounds.size, padding: padding)
    }

    private func contentBounds() -> CGRect {
        var result: CGRect?
        for node in scene.nodes.values {
            result = result?.union(node.frame) ?? node.frame
        }
        return result ?? CGRect(x: 0, y: 0, width: 800, height: 600)
    }

    // MARK: - Commands

    private func perform(_ command: any Command, actionName: String) {
        commandStack.perform(command, actionName: actionName)
        syncSpatialIndex(for: command.affectedObjectIDs)
        let prunedSelection = selection.intersection(scene.nodes.keys)
        if prunedSelection != selection {
            updateSelectionFromInteraction(prunedSelection)
        }
        needsDisplay = true
        onSceneChanged?()
    }

    /// An immutable snapshot of the live scene, for the app target to write
    /// into `DiagramDocument.model` (see `onSceneChanged`). Page-level
    /// fields (name/order/canvasSize/background) aren't tracked by
    /// `SceneStore` — the caller supplies the current values for those.
    public func currentPageSnapshot(name: String, order: Int, canvasSize: Size2D?, background: PageBackground) -> DiagramPage {
        scene.snapshot(name: name, order: order, canvasSize: canvasSize, background: background)
    }

    /// The Inspector's write path: applies `transform` to every currently
    /// selected node and commits one `UpdateNodesCommand`. Fields that only
    /// make sense for a single node (position/size/rotation) are the
    /// Inspector's responsibility to only show when `selection.count == 1`
    /// — this method itself is happy to apply the same transform across a
    /// multi-selection (e.g. setting fill color or criticality uniformly).
    public func updateSelectedNodes(actionName: String, _ transform: (inout DiagramNode) -> Void) {
        guard !selection.isEmpty else { return }
        var before: [NodeID: DiagramNode] = [:]
        var after: [NodeID: DiagramNode] = [:]
        for id in selection {
            guard let original = scene.nodes[id] else { continue }
            var updated = original
            transform(&updated)
            before[id] = original
            after[id] = updated
        }
        guard before != after else { return }
        perform(UpdateNodesCommand(before: before, after: after), actionName: actionName)
    }

    private func syncSpatialIndex(for ids: [AnyObjectID]) {
        for id in ids {
            guard case .node(let nodeID) = id else { continue }
            if let node = scene.nodes[nodeID] {
                spatialIndex.update(nodeID, bounds: node.frame)
            } else {
                spatialIndex.remove(nodeID)
            }
        }
    }

    /// Adds a new node of `type`, centered on `contentPoint` (defaults to
    /// the current viewport's center — e.g. for a sidebar-triggered add
    /// where there's no click location), and selects it.
    @discardableResult
    public func addNode(ofType type: ShapeType, at contentPoint: CGPoint? = nil) -> NodeID {
        let size = Size2D(width: 160, height: 100)
        let center = contentPoint ?? viewport.viewToContent(point: CGPoint(x: bounds.midX, y: bounds.midY))
        let maxZ = (scene.nodes.values.map(\.zIndex).max() ?? -1) + 1
        let node = DiagramNode(
            type: type,
            position: Point2D(x: center.x - size.width / 2, y: center.y - size.height / 2),
            size: size,
            zIndex: maxZ
        )
        perform(AddNodesCommand(nodes: [node]), actionName: "Add Shape")
        updateSelectionFromInteraction([node.id])
        return node.id
    }

    // MARK: - Delete / duplicate / copy / paste / z-order / select all

    @objc public func delete(_ sender: Any?) {
        guard !selection.isEmpty else { return }
        // Locked nodes are excluded, not deleted-then-warned-about — the
        // remaining (still-locked) selection stays selected afterward so
        // it's obvious those didn't disappear silently.
        let removed = selection.compactMap { scene.nodes[$0] }.filter { !$0.isLocked }
        guard !removed.isEmpty else { return }
        perform(RemoveNodesCommand(nodes: removed), actionName: "Delete")
        updateSelectionFromInteraction(selection.subtracting(removed.map(\.id)))
    }

    // MARK: - Lock / hide

    @objc public func toggleLock(_ sender: Any?) {
        updateSelectedNodes(actionName: "Toggle Lock") { $0.isLocked.toggle() }
    }

    @objc public func toggleHidden(_ sender: Any?) {
        updateSelectedNodes(actionName: "Toggle Hidden") { $0.isHidden.toggle() }
    }

    @objc public func duplicate(_ sender: Any?) {
        guard !selection.isEmpty else { return }
        let originals = selection.compactMap { scene.nodes[$0] }
        guard !originals.isEmpty else { return }
        let maxZ = (scene.nodes.values.map(\.zIndex).max() ?? -1)
        let copies = originals.enumerated().map { index, original -> DiagramNode in
            var copy = original
            copy.id = NodeID()
            copy.position = Point2D(x: original.position.x + 24, y: original.position.y + 24)
            copy.zIndex = maxZ + 1 + index
            copy.groupID = nil
            return copy
        }
        perform(AddNodesCommand(nodes: copies), actionName: "Duplicate")
        updateSelectionFromInteraction(Set(copies.map(\.id)))
    }

    private static let pasteboardType = NSPasteboard.PasteboardType("com.arqido.diagram.nodes")

    @objc public func copy(_ sender: Any?) {
        guard !selection.isEmpty else { return }
        let nodes = selection.compactMap { scene.nodes[$0] }
        guard let data = try? JSONEncoder().encode(nodes) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([Self.pasteboardType], owner: nil)
        pasteboard.setData(data, forType: Self.pasteboardType)
    }

    @objc public func cut(_ sender: Any?) {
        copy(sender)
        delete(sender)
    }

    @objc public func paste(_ sender: Any?) {
        guard let data = NSPasteboard.general.data(forType: Self.pasteboardType),
              let nodes = try? JSONDecoder().decode([DiagramNode].self, from: data),
              !nodes.isEmpty else { return }
        let maxZ = (scene.nodes.values.map(\.zIndex).max() ?? -1)
        let copies = nodes.enumerated().map { index, original -> DiagramNode in
            var copy = original
            copy.id = NodeID()
            copy.position = Point2D(x: original.position.x + 24, y: original.position.y + 24)
            copy.zIndex = maxZ + 1 + index
            copy.groupID = nil
            return copy
        }
        perform(AddNodesCommand(nodes: copies), actionName: "Paste")
        updateSelectionFromInteraction(Set(copies.map(\.id)))
    }

    @objc public override func selectAll(_ sender: Any?) {
        updateSelectionFromInteraction(Set(scene.nodes.keys))
    }

    @objc public func bringForward(_ sender: Any?) { reorderSelection(by: 1, actionName: "Bring Forward") }
    @objc public func sendBackward(_ sender: Any?) { reorderSelection(by: -1, actionName: "Send Backward") }

    private func reorderSelection(by direction: Int, actionName: String) {
        guard !selection.isEmpty else { return }
        let sortedAll = scene.nodes.values.sorted { $0.zIndex < $1.zIndex }
        var before: [NodeID: DiagramNode] = [:]
        var after: [NodeID: DiagramNode] = [:]

        let indices = direction > 0 ? Array(sortedAll.indices) : Array(sortedAll.indices.reversed())
        for index in indices {
            let node = sortedAll[index]
            guard selection.contains(node.id) else { continue }
            let neighborIndex = index + direction
            guard sortedAll.indices.contains(neighborIndex) else { continue }
            let neighbor = sortedAll[neighborIndex]
            guard !selection.contains(neighbor.id) else { continue }

            let currentNode = after[node.id] ?? node
            let currentNeighbor = after[neighbor.id] ?? neighbor
            before[node.id] = before[node.id] ?? node
            before[neighbor.id] = before[neighbor.id] ?? neighbor

            var updatedNode = currentNode
            var updatedNeighbor = currentNeighbor
            updatedNode.zIndex = currentNeighbor.zIndex
            updatedNeighbor.zIndex = currentNode.zIndex
            after[node.id] = updatedNode
            after[neighbor.id] = updatedNeighbor
        }

        guard !after.isEmpty else { return }
        perform(UpdateNodesCommand(before: before, after: after), actionName: actionName)
    }

    // MARK: - Alignment / distribution

    @objc public func alignLeft(_ sender: Any?) { align("Align Left") { bounds, node in node.position.x = bounds.minX } }
    @objc public func alignRight(_ sender: Any?) { align("Align Right") { bounds, node in node.position.x = bounds.maxX - node.size.width } }
    @objc public func alignCenterHorizontally(_ sender: Any?) { align("Align Center") { bounds, node in node.position.x = bounds.midX - node.size.width / 2 } }
    @objc public func alignTop(_ sender: Any?) { align("Align Top") { bounds, node in node.position.y = bounds.minY } }
    @objc public func alignBottom(_ sender: Any?) { align("Align Bottom") { bounds, node in node.position.y = bounds.maxY - node.size.height } }
    @objc public func alignMiddle(_ sender: Any?) { align("Align Middle") { bounds, node in node.position.y = bounds.midY - node.size.height / 2 } }

    private func align(_ actionName: String, _ transform: @escaping (CGRect, inout DiagramNode) -> Void) {
        guard selection.count > 1, let bounds = selectionBounds() else { return }
        updateSelectedNodes(actionName: actionName) { node in transform(bounds, &node) }
    }

    /// Distributes left edges (horizontal) / top edges (vertical) with
    /// equal spacing between the first and last node — a simpler rule than
    /// "equal gap accounting for each node's width," but a real, honest
    /// distribution rather than a half-implemented approximation of the
    /// fancier version.
    @objc public func distributeHorizontally(_ sender: Any?) { distribute("Distribute Horizontally") { $0.position.x } set: { $1.position.x = $0 } }
    @objc public func distributeVertically(_ sender: Any?) { distribute("Distribute Vertically") { $0.position.y } set: { $1.position.y = $0 } }

    private func distribute(_ actionName: String, _ axis: (DiagramNode) -> Double, set: @escaping (Double, inout DiagramNode) -> Void) {
        let nodes = selection.compactMap { scene.nodes[$0] }.sorted { axis($0) < axis($1) }
        guard nodes.count > 2, let first = nodes.first, let last = nodes.last else { return }
        let step = (axis(last) - axis(first)) / Double(nodes.count - 1)

        var before: [NodeID: DiagramNode] = [:]
        var after: [NodeID: DiagramNode] = [:]
        for (index, node) in nodes.enumerated() {
            var updated = node
            set(axis(first) + step * Double(index), &updated)
            before[node.id] = node
            after[node.id] = updated
        }
        guard before != after else { return }
        perform(UpdateNodesCommand(before: before, after: after), actionName: actionName)
    }

    // MARK: - Group / ungroup

    @objc public func groupSelection(_ sender: Any?) {
        guard selection.count > 1 else { return }
        let previousGroupIDs: [NodeID: GroupID?] = Dictionary(uniqueKeysWithValues: selection.compactMap { id in
            guard let node = scene.nodes[id] else { return nil }
            return (id, node.groupID)
        })
        let group = DiagramGroup(memberNodeIDs: selection)
        perform(GroupNodesCommand(group: group, previousGroupIDs: previousGroupIDs), actionName: "Group")
    }

    @objc public func ungroupSelection(_ sender: Any?) {
        let groupIDs = Set(selection.compactMap { scene.nodes[$0]?.groupID })
        guard !groupIDs.isEmpty else { return }
        let commands: [any Command] = groupIDs.compactMap { groupID -> (any Command)? in
            guard let group = scene.groups[groupID] else { return nil }
            // Phase 1 has no nested-group UI yet, so ungrouping always
            // returns members to top-level (nil), not some deeper prior
            // group — there's no deeper prior group to restore to.
            let previousGroupIDs: [NodeID: GroupID?] = Dictionary(uniqueKeysWithValues: group.memberNodeIDs.map { ($0, nil) })
            return UngroupNodesCommand(group: group, previousGroupIDs: previousGroupIDs)
        }
        guard !commands.isEmpty else { return }
        perform(CompositeCommand(commands), actionName: "Ungroup")
    }

    /// Clicking (or marquee-selecting) any member of a group selects the
    /// whole group — grouped shapes move/select together, per the spec's
    /// "Group / Ungroup" requirement.
    private func expandedForGrouping(_ ids: Set<NodeID>) -> Set<NodeID> {
        var result = ids
        for id in ids {
            if let groupID = scene.nodes[id]?.groupID, let group = scene.groups[groupID] {
                result.formUnion(group.memberNodeIDs)
            }
        }
        return result
    }

    public override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 51, 117: // Backspace, Forward Delete
            delete(nil)
        default:
            super.keyDown(with: event)
        }
    }

    // MARK: - Selection

    /// SwiftUI -> canvas direction (Inspector/search-driven selection, once
    /// those exist). Guarded against redundant work, but intentionally
    /// silent otherwise — see `onSelectionChange`'s doc comment for why this
    /// never echoes back out.
    public func applyExternalSelection(_ ids: Set<NodeID>) {
        guard selection != ids else { return }
        selection = ids
        needsDisplay = true
    }

    private func updateSelectionFromInteraction(_ ids: Set<NodeID>) {
        guard selection != ids else { return }
        selection = ids
        needsDisplay = true
        onSelectionChange?(selection)
    }

    /// Exact hit-test: `SpatialGrid` narrows to candidates near the point,
    /// then `ShapeGeometry`'s path (the same one `draw(_:in:)` uses, so
    /// hit-testing and drawing can never drift apart) decides which
    /// candidate — topmost by `zIndex` — was actually clicked. Rotated
    /// nodes are tested by rotating the click point into the node's local
    /// (unrotated) space, matching how `draw(_:in:)` rotates the context.
    private func topmostNode(at contentPoint: CGPoint) -> NodeID? {
        let probe = CGRect(x: contentPoint.x - 1, y: contentPoint.y - 1, width: 2, height: 2)
        let candidates = spatialIndex.query(probe)
            .compactMap { scene.nodes[$0] }
            .sorted { $0.zIndex > $1.zIndex }

        for node in candidates where !node.isHidden {
            let localPoint = node.rotation == 0
                ? contentPoint
                : rotatePoint(contentPoint, around: node.frame.center, by: -node.rotation)
            let path = ShapeGeometry.path(for: node.type, in: node.frame)
            if path.contains(localPoint) { return node.id }
        }
        return nil
    }

    private func selectionBounds() -> CGRect? {
        var result: CGRect?
        for id in selection {
            guard let node = scene.nodes[id] else { continue }
            result = result?.union(node.frame) ?? node.frame
        }
        return result
    }

    // MARK: - Text editing

    private var activeTextEditor: NSTextField?
    private var editingNodeID: NodeID?

    /// Double-click enters text editing via a real `NSTextField` overlaid
    /// exactly on the node's view-space frame — not a custom-drawn editing
    /// affordance. Rendering the committed text (when not editing) is
    /// `drawText(_:in:)`, via `NSAttributedString.draw(in:)`.
    private func beginTextEditing(_ id: NodeID) {
        guard let node = scene.nodes[id] else { return }
        endTextEditing(commit: true)

        let viewFrame = node.frame.applying(viewport.contentToViewTransform)
        let field = NSTextField(frame: viewFrame)
        field.stringValue = node.text?.string ?? ""
        field.isBordered = true
        field.backgroundColor = .textBackgroundColor
        field.font = .systemFont(ofSize: CGFloat(node.style.font?.size ?? 13))
        field.alignment = .center
        field.delegate = self
        field.usesSingleLineMode = false
        field.cell?.wraps = true

        addSubview(field)
        window?.makeFirstResponder(field)
        activeTextEditor = field
        editingNodeID = id
    }

    private func endTextEditing(commit: Bool) {
        guard let field = activeTextEditor, let id = editingNodeID else { return }
        if commit, let original = scene.nodes[id] {
            var updated = original
            let trimmed = field.stringValue
            updated.text = trimmed.isEmpty ? nil : TextContent(string: trimmed)
            if updated != original {
                perform(UpdateNodesCommand(before: [id: original], after: [id: updated]), actionName: "Edit Text")
            }
        }
        field.removeFromSuperview()
        activeTextEditor = nil
        editingNodeID = nil
        window?.makeFirstResponder(self)
    }

    private func drawText(_ node: DiagramNode, in context: CGContext) {
        guard let text = node.text, !text.string.isEmpty, node.id != editingNodeID else { return }

        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: isFlipped)
        defer { NSGraphicsContext.current = previous }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributed = NSAttributedString(string: text.string, attributes: [
            .font: NSFont.systemFont(ofSize: CGFloat(node.style.font?.size ?? 13)),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ])

        let insetRect = node.frame.insetBy(dx: 6, dy: 6)
        let fitted = attributed.boundingRect(with: insetRect.size, options: [.usesLineFragmentOrigin])
        let drawRect = CGRect(x: insetRect.minX, y: insetRect.midY - fitted.height / 2, width: insetRect.width, height: fitted.height)
        attributed.draw(with: drawRect, options: [.usesLineFragmentOrigin])
    }

    // MARK: - Mouse / gestures

    private enum DragMode {
        case none
        case marquee
        case move(startPositions: [NodeID: Point2D], startContentPoint: CGPoint)
        case resize(handle: ResizeHandle, startBounds: CGRect, startFrames: [NodeID: CGRect])
        case rotate(nodeID: NodeID, center: CGPoint, startAngle: CGFloat, startRotation: Double)
        case connector(sourceNodeID: NodeID, currentContentPoint: CGPoint)
    }

    private var dragMode: DragMode = .none
    private var marqueeStartView: CGPoint?
    private var marqueeCurrentView: CGPoint?

    private var marqueeViewRect: CGRect? {
        guard let start = marqueeStartView, let current = marqueeCurrentView else { return nil }
        return CGRect(
            x: min(start.x, current.x), y: min(start.y, current.y),
            width: abs(current.x - start.x), height: abs(current.y - start.y)
        )
    }

    /// View-space hit radius for handles — a fixed pixel tolerance
    /// regardless of zoom, matching how the handles themselves are drawn at
    /// a fixed view-space size.
    private static let handleHitRadius: CGFloat = 6
    private static let rotationHandleOffset: CGFloat = 34

    private func hitResizeHandle(atView viewPoint: CGPoint) -> (ResizeHandle, CGRect)? {
        guard let bounds = selectionBounds() else { return nil }
        let viewBounds = bounds.applying(viewport.contentToViewTransform)
        for handle in ResizeHandle.allCases {
            let handlePoint = handle.point(in: viewBounds)
            if hypot(handlePoint.x - viewPoint.x, handlePoint.y - viewPoint.y) <= Self.handleHitRadius {
                return (handle, bounds)
            }
        }
        return nil
    }

    private func hitRotationHandle(atView viewPoint: CGPoint) -> NodeID? {
        guard selection.count == 1, let id = selection.first, let node = scene.nodes[id] else { return nil }
        let viewFrame = node.frame.applying(viewport.contentToViewTransform)
        let rotatedTop = rotatePoint(
            CGPoint(x: viewFrame.midX, y: viewFrame.minY - Self.rotationHandleOffset),
            around: viewFrame.center,
            by: CGFloat(node.rotation)
        )
        return hypot(rotatedTop.x - viewPoint.x, rotatedTop.y - viewPoint.y) <= Self.handleHitRadius ? id : nil
    }

    /// The 4 connector "ports" (N/S/E/W), shown only when exactly one node
    /// is selected. Offset outward from the frame in *view* space (a fixed
    /// pixel amount, unaffected by zoom) so they sit in their own hit-test
    /// ring — between the resize handles (right on the boundary) and the
    /// rotation handle (further out) — rather than overlapping either.
    private static let connectorHandleOffset: CGFloat = 18

    private func connectorHandleViewPoints(for node: DiagramNode) -> [CGPoint] {
        let f = node.frame.applying(viewport.contentToViewTransform)
        let o = Self.connectorHandleOffset
        return [
            CGPoint(x: f.midX, y: f.minY - o), CGPoint(x: f.midX, y: f.maxY + o),
            CGPoint(x: f.minX - o, y: f.midY), CGPoint(x: f.maxX + o, y: f.midY)
        ]
    }

    private func hitConnectorHandle(atView viewPoint: CGPoint) -> NodeID? {
        guard selection.count == 1, let id = selection.first, let node = scene.nodes[id] else { return nil }
        for handlePoint in connectorHandleViewPoints(for: node) {
            if hypot(handlePoint.x - viewPoint.x, handlePoint.y - viewPoint.y) <= Self.handleHitRadius {
                return id
            }
        }
        return nil
    }

    private func drawConnectorHandles(for node: DiagramNode, in context: CGContext) {
        context.saveGState()
        context.setFillColor(NSColor.systemGreen.cgColor)
        for p in connectorHandleViewPoints(for: node) {
            context.fillEllipse(in: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8))
        }
        context.restoreGState()
    }

    private func pendingConnectorPreview() -> (CGPoint, CGPoint)? {
        guard case .connector(let sourceID, let currentPoint) = dragMode, let sourceNode = scene.nodes[sourceID] else { return nil }
        let source = EdgeGeometry.clippedPoint(from: sourceNode.frame.center, towards: currentPoint, in: sourceNode.frame)
        return (source, currentPoint)
    }

    public override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let viewPoint = convert(event.locationInWindow, from: nil)
        let contentPoint = viewport.viewToContent(point: viewPoint)
        let isExtending = event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.command)

        if event.clickCount >= 2, let hitID = topmostNode(at: contentPoint) {
            beginTextEditing(hitID)
            return
        }

        if !isExtending, let sourceID = hitConnectorHandle(atView: viewPoint) {
            dragMode = .connector(sourceNodeID: sourceID, currentContentPoint: contentPoint)
            return
        }

        if !isExtending, !selection.isEmpty, let (handle, bounds) = hitResizeHandle(atView: viewPoint) {
            let frames = Dictionary(uniqueKeysWithValues: selection.compactMap { id -> (NodeID, CGRect)? in
                guard let node = scene.nodes[id], !node.isLocked else { return nil }
                return (id, node.frame)
            })
            dragMode = .resize(handle: handle, startBounds: bounds, startFrames: frames)
            return
        }

        if !isExtending, let rotateID = hitRotationHandle(atView: viewPoint), let node = scene.nodes[rotateID], !node.isLocked {
            let center = node.frame.center
            let startAngle = atan2(contentPoint.y - center.y, contentPoint.x - center.x)
            dragMode = .rotate(nodeID: rotateID, center: center, startAngle: startAngle, startRotation: node.rotation)
            return
        }

        if let hitID = topmostNode(at: contentPoint) {
            let hitGroup = expandedForGrouping([hitID])
            if isExtending {
                var updated = selection
                if updated.isSuperset(of: hitGroup) { updated.subtract(hitGroup) } else { updated.formUnion(hitGroup) }
                updateSelectionFromInteraction(updated)
                dragMode = .none
            } else {
                if !selection.isSuperset(of: hitGroup) {
                    updateSelectionFromInteraction(hitGroup)
                }
                let startPositions = Dictionary(uniqueKeysWithValues: selection.compactMap { id -> (NodeID, Point2D)? in
                    guard let node = scene.nodes[id], !node.isLocked else { return nil }
                    return (id, node.position)
                })
                dragMode = .move(startPositions: startPositions, startContentPoint: contentPoint)
            }
        } else {
            if !isExtending {
                updateSelectionFromInteraction([])
            }
            dragMode = .marquee
            marqueeStartView = viewPoint
            marqueeCurrentView = viewPoint
        }
    }

    public override func mouseDragged(with event: NSEvent) {
        let viewPoint = convert(event.locationInWindow, from: nil)
        let contentPoint = viewport.viewToContent(point: viewPoint)

        switch dragMode {
        case .none:
            return
        case .marquee:
            marqueeCurrentView = viewPoint
            needsDisplay = true
        case .move(let startPositions, let startContentPoint):
            let dx = contentPoint.x - startContentPoint.x
            let dy = contentPoint.y - startContentPoint.y
            for (id, startPosition) in startPositions {
                guard var node = scene.nodes[id] else { continue }
                node.position = Point2D(x: startPosition.x + dx, y: startPosition.y + dy)
                scene.setNode(node)
                spatialIndex.update(id, bounds: node.frame)
            }
            needsDisplay = true
        case .resize(let handle, let startBounds, let startFrames):
            let newBounds = handle.resized(from: startBounds, draggedTo: contentPoint)
            applyLiveResize(startBounds: startBounds, newBounds: newBounds, startFrames: startFrames)
        case .rotate(let nodeID, let center, let startAngle, let startRotation):
            guard var node = scene.nodes[nodeID] else { return }
            let currentAngle = atan2(contentPoint.y - center.y, contentPoint.x - center.x)
            node.rotation = startRotation + Double(currentAngle - startAngle)
            scene.setNode(node)
            needsDisplay = true
        case .connector(let sourceID, _):
            dragMode = .connector(sourceNodeID: sourceID, currentContentPoint: contentPoint)
            needsDisplay = true
        }
    }

    /// Live preview during an active resize drag — mutates `scene` directly
    /// (see `CommandStack`'s doc comment on why gesture preview is the one
    /// intentional exception to "always go through a Command"). Exactly one
    /// `UpdateNodesCommand` commits the net effect at `mouseUp`.
    private func applyLiveResize(startBounds: CGRect, newBounds: CGRect, startFrames: [NodeID: CGRect]) {
        guard startBounds.width > 0, startBounds.height > 0 else { return }
        let scaleX = newBounds.width / startBounds.width
        let scaleY = newBounds.height / startBounds.height

        for (id, startFrame) in startFrames {
            guard var node = scene.nodes[id] else { continue }
            let relX = (startFrame.minX - startBounds.minX) * scaleX
            let relY = (startFrame.minY - startBounds.minY) * scaleY
            node.position = Point2D(x: newBounds.minX + relX, y: newBounds.minY + relY)
            node.size = Size2D(width: startFrame.width * scaleX, height: startFrame.height * scaleY)
            scene.setNode(node)
            spatialIndex.update(id, bounds: node.frame)
        }
        needsDisplay = true
    }

    public override func mouseUp(with event: NSEvent) {
        defer { dragMode = .none }

        switch dragMode {
        case .none:
            break

        case .marquee:
            defer {
                marqueeStartView = nil
                marqueeCurrentView = nil
                needsDisplay = true
            }
            guard let viewRect = marqueeViewRect, viewRect.width > 2 || viewRect.height > 2 else { return }
            let contentRect = viewport.viewToContent(rect: viewRect)
            let hits = spatialIndex.query(contentRect).filter { id in
                guard let node = scene.nodes[id] else { return false }
                return contentRect.intersects(node.frame)
            }
            let expandedHits = expandedForGrouping(Set(hits))
            let isExtending = event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.command)
            updateSelectionFromInteraction(isExtending ? selection.union(expandedHits) : expandedHits)

        case .move(let startPositions, _):
            var before: [NodeID: DiagramNode] = [:]
            var after: [NodeID: DiagramNode] = [:]
            for (id, startPosition) in startPositions {
                guard let current = scene.nodes[id] else { continue }
                var original = current
                original.position = startPosition
                before[id] = original
                after[id] = current
            }
            guard before != after else { return }
            commitLiveChange(before: before, after: after, actionName: "Move")

        case .resize(_, let startBounds, let startFrames):
            var before: [NodeID: DiagramNode] = [:]
            var after: [NodeID: DiagramNode] = [:]
            for (id, startFrame) in startFrames {
                guard let current = scene.nodes[id] else { continue }
                var original = current
                original.position = Point2D(x: startFrame.minX, y: startFrame.minY)
                original.size = Size2D(width: startFrame.width, height: startFrame.height)
                before[id] = original
                after[id] = current
            }
            guard before != after else { return }
            commitLiveChange(before: before, after: after, actionName: "Resize")
            _ = startBounds

        case .rotate(let nodeID, _, _, let startRotation):
            guard let current = scene.nodes[nodeID] else { return }
            var original = current
            original.rotation = startRotation
            guard original != current else { return }
            commitLiveChange(before: [nodeID: original], after: [nodeID: current], actionName: "Rotate")

        case .connector(let sourceID, let currentContentPoint):
            defer { needsDisplay = true }
            let target: EndpointRef
            if let targetID = topmostNode(at: currentContentPoint), targetID != sourceID {
                target = .node(targetID, portID: nil)
            } else {
                target = .point(Point2D(x: currentContentPoint.x, y: currentContentPoint.y))
            }
            let edge = DiagramEdge(source: .node(sourceID, portID: nil), target: target)
            perform(AddEdgesCommand(edges: [edge]), actionName: "Connect")
        }
    }

    /// Registers undo for a gesture whose *live preview* already mutated
    /// `scene` directly (drag-move/resize/rotate) — `before`/`after` are
    /// full node snapshots, so `UpdateNodesCommand.apply` re-setting `after`
    /// on top of values that already equal `after` is a harmless no-op,
    /// never a double-move.
    private func commitLiveChange(before: [NodeID: DiagramNode], after: [NodeID: DiagramNode], actionName: String) {
        commandStack.perform(UpdateNodesCommand(before: before, after: after), actionName: actionName)
        onSceneChanged?()
    }

    // MARK: - Drawing

    public override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.setFillColor(NSColor.textBackgroundColor.cgColor)
        context.fill(dirtyRect)

        context.saveGState()
        context.concatenate(viewport.contentToViewTransform)

        // Edges draw behind nodes — endpoints are clipped to the node
        // boundary (EdgeGeometry.clippedPoint), so drawing nodes on top
        // covers any line stub that would otherwise poke past the edge.
        for edge in scene.edges.values.sorted(by: { $0.zIndex < $1.zIndex }) {
            drawEdge(edge, in: context)
        }

        let contentDirtyRect = viewport.viewToContent(rect: dirtyRect)
        let candidateIDs = spatialIndex.query(contentDirtyRect)
        let visibleNodes = candidateIDs.compactMap { scene.nodes[$0] }.sorted { $0.zIndex < $1.zIndex }
        for node in visibleNodes {
            draw(node, in: context)
        }

        if let connectorPreview = pendingConnectorPreview() {
            context.saveGState()
            context.setStrokeColor(NSColor.controlAccentColor.cgColor)
            context.setLineWidth(1.5 / viewport.scale)
            context.setLineDash(phase: 0, lengths: [6 / viewport.scale, 4 / viewport.scale])
            context.addPath(EdgeGeometry.path(from: connectorPreview.0, to: connectorPreview.1, routing: .straight))
            context.strokePath()
            context.restoreGState()
        }

        context.restoreGState()

        // Selection handles and the marquee are drawn in view space (after
        // restoring the content transform) so their line width stays a
        // crisp, constant 1-2px regardless of zoom — matching how AppKit's
        // own selection chrome behaves.
        if !selection.isEmpty {
            drawSelectionHighlights(in: context)
        }
        if selection.count == 1, let id = selection.first, let node = scene.nodes[id] {
            drawConnectorHandles(for: node, in: context)
        }
        if let marqueeRect = marqueeViewRect {
            drawMarquee(marqueeRect, in: context)
        }
    }

    private func drawEdge(_ edge: DiagramEdge, in context: CGContext) {
        guard !edge.isHidden else { return }
        // Resolve towards the other endpoint's node center (or its own
        // point) as the "aim" reference for boundary-clipping.
        let targetAim = aimPoint(for: edge.target)
        let sourceAim = aimPoint(for: edge.source)
        guard let source = EdgeGeometry.resolvedPoint(for: edge.source, nodes: scene.nodes, towards: targetAim),
              let target = EdgeGeometry.resolvedPoint(for: edge.target, nodes: scene.nodes, towards: sourceAim) else { return }

        let path = EdgeGeometry.path(from: source, to: target, routing: edge.routing)
        context.saveGState()
        context.setStrokeColor(NSColor(edge.style.strokeColor ?? .system(.systemGray)).cgColor)
        context.setLineWidth(max(edge.style.strokeWidth, 0.5) / viewport.scale)
        if edge.style.dash == .dashed {
            context.setLineDash(phase: 0, lengths: [6 / viewport.scale, 4 / viewport.scale])
        } else if edge.style.dash == .dotted {
            context.setLineDash(phase: 0, lengths: [1.5 / viewport.scale, 3 / viewport.scale])
        }
        context.addPath(path)
        context.strokePath()

        let arrowColor = NSColor(edge.style.strokeColor ?? .system(.systemGray)).cgColor
        if let startArrow = EdgeGeometry.arrowheadPath(from: target, tip: source, style: edge.style.startArrow, size: 9 / viewport.scale) {
            context.setFillColor(arrowColor)
            context.addPath(startArrow)
            context.drawPath(using: edge.style.startArrow == .filled || edge.style.startArrow == .diamond || edge.style.startArrow == .circle ? .fillStroke : .stroke)
        }
        if let endArrow = EdgeGeometry.arrowheadPath(from: source, tip: target, style: edge.style.endArrow, size: 9 / viewport.scale) {
            context.setFillColor(arrowColor)
            context.addPath(endArrow)
            context.drawPath(using: edge.style.endArrow == .filled || edge.style.endArrow == .diamond || edge.style.endArrow == .circle ? .fillStroke : .stroke)
        }
        context.restoreGState()
    }

    private func aimPoint(for endpoint: EndpointRef) -> CGPoint {
        switch endpoint {
        case .point(let p): return CGPoint(x: p.x, y: p.y)
        case .node(let id, _): return scene.nodes[id]?.frame.center ?? .zero
        }
    }

    private func draw(_ node: DiagramNode, in context: CGContext) {
        guard !node.isHidden else { return }
        let path = ShapeGeometry.path(for: node.type, in: node.frame)

        let fillColor = NSColor(node.style.fill ?? .system(.systemBlue))
        let strokeColor = NSColor(node.style.strokeColor ?? .system(.systemGray))

        context.saveGState()
        if node.rotation != 0 {
            let center = node.frame.center
            context.translateBy(x: center.x, y: center.y)
            context.rotate(by: CGFloat(node.rotation))
            context.translateBy(x: -center.x, y: -center.y)
        }
        context.setAlpha(node.style.opacity)
        context.addPath(path)
        context.setFillColor(fillColor.cgColor)
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(max(node.style.strokeWidth, 0.5) / viewport.scale)
        context.drawPath(using: node.style.strokeWidth > 0 ? .fillStroke : .fill)
        drawText(node, in: context) // inside the same rotation transform, so text rotates with the shape
        context.restoreGState()
    }

    private func drawSelectionHighlights(in context: CGContext) {
        context.saveGState()
        context.setStrokeColor(NSColor.controlAccentColor.cgColor)
        context.setLineWidth(2)
        var combinedContentBounds: CGRect?
        for id in selection {
            guard let node = scene.nodes[id] else { continue }
            let viewRect = node.frame.applying(viewport.contentToViewTransform)
            if node.rotation == 0 {
                context.stroke(viewRect.insetBy(dx: -3, dy: -3))
            } else {
                strokeRotatedOutline(of: node, in: context)
            }
            combinedContentBounds = combinedContentBounds?.union(node.frame) ?? node.frame
        }
        context.restoreGState()

        guard let combined = combinedContentBounds else { return }
        let combinedViewRect = combined.applying(viewport.contentToViewTransform)

        // A dashed combined bounding box only reads as meaningful once
        // there's more than one object to bound together.
        if selection.count > 1 {
            context.saveGState()
            context.setStrokeColor(NSColor.secondaryLabelColor.cgColor)
            context.setLineWidth(1)
            context.setLineDash(phase: 0, lengths: [4, 3])
            context.stroke(combinedViewRect.insetBy(dx: -8, dy: -8))
            context.restoreGState()
        }

        drawResizeHandles(around: combinedViewRect, in: context)
        if selection.count == 1, let id = selection.first, let node = scene.nodes[id] {
            drawRotationHandle(for: node, in: context)
        }
    }

    private func strokeRotatedOutline(of node: DiagramNode, in context: CGContext) {
        let viewFrame = node.frame.applying(viewport.contentToViewTransform)
        let inset = viewFrame.insetBy(dx: -3, dy: -3)
        let corners = [
            CGPoint(x: inset.minX, y: inset.minY), CGPoint(x: inset.maxX, y: inset.minY),
            CGPoint(x: inset.maxX, y: inset.maxY), CGPoint(x: inset.minX, y: inset.maxY)
        ].map { rotatePoint($0, around: viewFrame.center, by: CGFloat(node.rotation)) }

        let path = CGMutablePath()
        path.addLines(between: corners)
        path.closeSubpath()
        context.addPath(path)
        context.strokePath()
    }

    private static let handleSize: CGFloat = 7

    private func drawResizeHandles(around viewRect: CGRect, in context: CGContext) {
        context.saveGState()
        context.setFillColor(NSColor.controlBackgroundColor.cgColor)
        context.setStrokeColor(NSColor.controlAccentColor.cgColor)
        context.setLineWidth(1)
        for handle in ResizeHandle.allCases {
            let center = handle.point(in: viewRect)
            let rect = CGRect(
                x: center.x - Self.handleSize / 2, y: center.y - Self.handleSize / 2,
                width: Self.handleSize, height: Self.handleSize
            )
            context.fillEllipse(in: rect)
            context.strokeEllipse(in: rect)
        }
        context.restoreGState()
    }

    private func drawRotationHandle(for node: DiagramNode, in context: CGContext) {
        let viewFrame = node.frame.applying(viewport.contentToViewTransform)
        let unrotatedTop = CGPoint(x: viewFrame.midX, y: viewFrame.minY - Self.rotationHandleOffset)
        let handleCenter = rotatePoint(unrotatedTop, around: viewFrame.center, by: CGFloat(node.rotation))
        let attachPoint = rotatePoint(CGPoint(x: viewFrame.midX, y: viewFrame.minY), around: viewFrame.center, by: CGFloat(node.rotation))

        context.saveGState()
        context.setStrokeColor(NSColor.controlAccentColor.cgColor)
        context.setLineWidth(1)
        context.move(to: attachPoint)
        context.addLine(to: handleCenter)
        context.strokePath()

        let handleRect = CGRect(
            x: handleCenter.x - Self.handleSize / 2, y: handleCenter.y - Self.handleSize / 2,
            width: Self.handleSize, height: Self.handleSize
        )
        context.setFillColor(NSColor.controlBackgroundColor.cgColor)
        context.fillEllipse(in: handleRect)
        context.strokeEllipse(in: handleRect)
        context.restoreGState()
    }

    /// Full-view invalidation during marquee drag (via `needsDisplay = true`
    /// in `mouseDragged`) is intentional, not a lapse in the dirty-rect
    /// discipline: the marquee itself sweeps across large, arbitrary regions
    /// each frame, so there's no small dirty rect to compute for "old
    /// marquee ∪ new marquee" — unlike node drag/resize, which mutate a
    /// bounded, known set of nodes.
    private func drawMarquee(_ rect: CGRect, in context: CGContext) {
        context.saveGState()
        context.setFillColor(NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor)
        context.fill(rect)
        context.setStrokeColor(NSColor.controlAccentColor.cgColor)
        context.setLineWidth(1)
        context.stroke(rect)
        context.restoreGState()
    }

    // MARK: - Pan / zoom

    public override func scrollWheel(with event: NSEvent) {
        let contentDelta = CGVector(dx: -event.scrollingDeltaX / viewport.scale, dy: -event.scrollingDeltaY / viewport.scale)
        viewport.contentOrigin.x += contentDelta.dx
        viewport.contentOrigin.y += contentDelta.dy
    }

    public override func magnify(with event: NSEvent) {
        let viewPoint = convert(event.locationInWindow, from: nil)
        let contentPointBefore = viewport.viewToContent(point: viewPoint)

        viewport.scale = (viewport.scale * (1 + event.magnification))
            .clamped(to: CanvasViewport.minScale...CanvasViewport.maxScale)

        let contentPointAfter = viewport.viewToContent(point: viewPoint)
        viewport.contentOrigin.x += contentPointBefore.x - contentPointAfter.x
        viewport.contentOrigin.y += contentPointBefore.y - contentPointAfter.y
    }
}

extension DiagramNode {
    var frame: CGRect {
        CGRect(x: position.x, y: position.y, width: size.width, height: size.height)
    }
}

extension DiagramCanvasView: NSTextFieldDelegate {
    public func controlTextDidEndEditing(_ obj: Notification) {
        endTextEditing(commit: true)
    }

    public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            endTextEditing(commit: false)
            return true
        }
        return false
    }
}
