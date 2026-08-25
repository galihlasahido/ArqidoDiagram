import Foundation

/// The live, in-place-mutable editing representation of the *currently
/// active* page — a reference type, deliberately not `@Published`/
/// `ObservableObject`. Mirrors `DiagramPage`'s flat-dictionary-plus-z-order
/// shape but is mutated directly during interactive gestures (drags,
/// resizes) to avoid `DiagramPage` value-type CoW churn on every mouse-move
/// tick. Reconciled into an immutable `DiagramPage` snapshot only when a
/// Command commits (undo-stack snapshot / autosave trigger) — see
/// `snapshot()`/`load(from:)`.
///
/// `DiagramRendering` reads this directly to draw (never through SwiftUI
/// state); `DiagramCommands` mutates it; SwiftUI observes only small,
/// coarse derived view-models (selection, canvas status), never this store.
public final class SceneStore {
    public private(set) var pageID: PageID
    public private(set) var nodes: [NodeID: DiagramNode]
    public private(set) var edges: [EdgeID: DiagramEdge]
    public private(set) var groups: [GroupID: DiagramGroup]
    public private(set) var nodeZOrder: [NodeID]
    public private(set) var edgeZOrder: [EdgeID]

    public init(page: DiagramPage) {
        self.pageID = page.id
        self.nodes = page.nodes
        self.edges = page.edges
        self.groups = page.groups
        self.nodeZOrder = page.nodeZOrder
        self.edgeZOrder = page.edgeZOrder
    }

    /// Replaces the store's contents in place with another page's data
    /// (used when switching the active page, or reloading after undo).
    public func load(from page: DiagramPage) {
        pageID = page.id
        nodes = page.nodes
        edges = page.edges
        groups = page.groups
        nodeZOrder = page.nodeZOrder
        edgeZOrder = page.edgeZOrder
    }

    /// An immutable snapshot suitable for persistence or an undo-stack entry.
    public func snapshot(name: String, order: Int, canvasSize: Size2D?, background: PageBackground) -> DiagramPage {
        DiagramPage(
            id: pageID,
            name: name,
            order: order,
            canvasSize: canvasSize,
            background: background,
            nodes: nodes,
            edges: edges,
            groups: groups,
            nodeZOrder: nodeZOrder,
            edgeZOrder: edgeZOrder
        )
    }

    public func setNode(_ node: DiagramNode) {
        let isNew = nodes[node.id] == nil
        nodes[node.id] = node
        if isNew { nodeZOrder.append(node.id) }
    }

    public func removeNode(_ id: NodeID) {
        nodes.removeValue(forKey: id)
        nodeZOrder.removeAll { $0 == id }
    }

    public func setEdge(_ edge: DiagramEdge) {
        let isNew = edges[edge.id] == nil
        edges[edge.id] = edge
        if isNew { edgeZOrder.append(edge.id) }
    }

    public func removeEdge(_ id: EdgeID) {
        edges.removeValue(forKey: id)
        edgeZOrder.removeAll { $0 == id }
    }

    public func setGroup(_ group: DiagramGroup) {
        groups[group.id] = group
    }

    public func removeGroup(_ id: GroupID) {
        groups.removeValue(forKey: id)
    }
}
