import Foundation

public struct DiagramGroup: Codable, Identifiable, Sendable {
    public var id: GroupID
    public var memberNodeIDs: Set<NodeID>
    public var memberEdgeIDs: Set<EdgeID>
    /// Supports nested groups without a physical containment tree — a
    /// group's flattened membership is resolved by a bounded walk only on
    /// group/ungroup operations, not on every frame.
    public var memberGroupIDs: Set<GroupID>
    public var name: String?

    public init(
        id: GroupID = GroupID(),
        memberNodeIDs: Set<NodeID> = [],
        memberEdgeIDs: Set<EdgeID> = [],
        memberGroupIDs: Set<GroupID> = [],
        name: String? = nil
    ) {
        self.id = id
        self.memberNodeIDs = memberNodeIDs
        self.memberEdgeIDs = memberEdgeIDs
        self.memberGroupIDs = memberGroupIDs
        self.name = name
    }
}
