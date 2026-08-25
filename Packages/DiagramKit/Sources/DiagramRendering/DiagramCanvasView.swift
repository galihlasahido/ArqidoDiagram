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
/// TODO(later build-order steps): text rendering/editing (step 11), edges
/// (step 13).
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
        let removed = selection.compactMap { scene.nodes[$0] }
        guard !removed.isEmpty else { return }
        perform(RemoveNodesCommand(nodes: removed), actionName: "Delete")
        updateSelectionFromInteraction([])
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

    // MARK: - Mouse / gestures

    private enum DragMode {
        case none
        case marquee
        case move(startPositions: [NodeID: Point2D], startContentPoint: CGPoint)
        case resize(handle: ResizeHandle, startBounds: CGRect, startFrames: [NodeID: CGRect])
        case rotate(nodeID: NodeID, center: CGPoint, startAngle: CGFloat, startRotation: Double)
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
    private static let rotationHandleOffset: CGFloat = 26

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

    public override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let viewPoint = convert(event.locationInWindow, from: nil)
        let contentPoint = viewport.viewToContent(point: viewPoint)
        let isExtending = event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.command)

        if !isExtending, !selection.isEmpty, let (handle, bounds) = hitResizeHandle(atView: viewPoint) {
            let frames = Dictionary(uniqueKeysWithValues: selection.compactMap { id -> (NodeID, CGRect)? in
                guard let node = scene.nodes[id] else { return nil }
                return (id, node.frame)
            })
            dragMode = .resize(handle: handle, startBounds: bounds, startFrames: frames)
            return
        }

        if !isExtending, let rotateID = hitRotationHandle(atView: viewPoint), let node = scene.nodes[rotateID] {
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
                    guard let node = scene.nodes[id] else { return nil }
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

        let contentDirtyRect = viewport.viewToContent(rect: dirtyRect)
        let candidateIDs = spatialIndex.query(contentDirtyRect)
        let visibleNodes = candidateIDs.compactMap { scene.nodes[$0] }.sorted { $0.zIndex < $1.zIndex }
        for node in visibleNodes {
            draw(node, in: context)
        }

        context.restoreGState()

        // Selection handles and the marquee are drawn in view space (after
        // restoring the content transform) so their line width stays a
        // crisp, constant 1-2px regardless of zoom — matching how AppKit's
        // own selection chrome behaves.
        if !selection.isEmpty {
            drawSelectionHighlights(in: context)
        }
        if let marqueeRect = marqueeViewRect {
            drawMarquee(marqueeRect, in: context)
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
        context.restoreGState()

        // TODO(step 11): draw node.text via CTFramesetter/NSAttributedString.
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
