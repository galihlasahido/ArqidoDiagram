import DiagramModel

/// A pure, deterministic `DiagramPage -> DiagramPage` transform. The
/// canvas/UI layer only ever calls through this protocol (see
/// `DiagramCanvasView.applyLayout`) — it never contains layout math itself,
/// per the spec's "do not hard-code layout logic into the UI".
public protocol LayoutEngine: Sendable {
    var displayName: String { get }
    func layout(_ page: DiagramPage) -> DiagramPage
}

/// The six algorithms the spec calls for, plus a factory so the UI can
/// offer them as a flat list without knowing any concrete engine type.
public enum LayoutKind: String, CaseIterable, Sendable {
    case hierarchical, tree, grid, forceDirected, circular, orthogonal

    public var displayName: String {
        switch self {
        case .hierarchical: return "Hierarchical"
        case .tree: return "Tree"
        case .grid: return "Grid"
        case .forceDirected: return "Force-Directed"
        case .circular: return "Circular"
        case .orthogonal: return "Orthogonal"
        }
    }

    public var engine: any LayoutEngine {
        switch self {
        case .hierarchical: return HierarchicalLayoutEngine()
        case .tree: return TreeLayoutEngine()
        case .grid: return GridLayoutEngine()
        case .forceDirected: return ForceDirectedLayoutEngine()
        case .circular: return CircularLayoutEngine()
        case .orthogonal: return OrthogonalLayoutEngine()
        }
    }
}

enum LayoutSupport {
    /// The page's own z-order, not arbitrary dictionary order — every
    /// engine below is deterministic (same input always produces the same
    /// output), which the z-order ordering is what makes possible.
    static func orderedNodes(_ page: DiagramPage) -> [DiagramNode] {
        page.nodeZOrder.compactMap { page.nodes[$0] }
    }
}
