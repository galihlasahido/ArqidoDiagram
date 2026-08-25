import Foundation

public struct NodeID: Hashable, Codable, Sendable {
    public let raw: UUID
    public init(_ raw: UUID = UUID()) { self.raw = raw }
}

public struct EdgeID: Hashable, Codable, Sendable {
    public let raw: UUID
    public init(_ raw: UUID = UUID()) { self.raw = raw }
}

public struct PageID: Hashable, Codable, Sendable {
    public let raw: UUID
    public init(_ raw: UUID = UUID()) { self.raw = raw }
}

public struct GroupID: Hashable, Codable, Sendable {
    public let raw: UUID
    public init(_ raw: UUID = UUID()) { self.raw = raw }
}

public struct PortID: Hashable, Codable, Sendable {
    public let raw: UUID
    public init(_ raw: UUID = UUID()) { self.raw = raw }
}

public struct CustomComponentID: Hashable, Codable, Sendable {
    public let raw: UUID
    public init(_ raw: UUID = UUID()) { self.raw = raw }
}
