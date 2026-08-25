import Foundation

/// Spec §VERSIONING: "Snapshot, Restore, Compare, Version notes". A version
/// is a full, standalone copy of the document at some point in time (not a
/// diff/patch chain) — simplest to get right, and the copies are small
/// enough (a diagram is at most a few thousand nodes) that storing full
/// snapshots costs nothing that matters. "Restore" is just "make this
/// snapshot the current model" (`DiagramDocument.restoreVersion`);
/// "Compare" is `VersionComparator.diff` below.
public struct DocumentVersion: Codable, Identifiable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let note: String
    public let snapshot: DiagramDocumentModel

    public init(id: UUID = UUID(), createdAt: Date = Date(), note: String, snapshot: DiagramDocumentModel) {
        self.id = id
        self.createdAt = createdAt
        self.note = note
        self.snapshot = snapshot
    }

    public var summary: VersionSummary {
        VersionSummary(id: id, createdAt: createdAt, note: note)
    }
}

/// The lightweight, list-friendly half of a `DocumentVersion` — everything
/// except the (potentially large) snapshot itself.
public struct VersionSummary: Codable, Identifiable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let note: String

    public init(id: UUID, createdAt: Date, note: String) {
        self.id = id
        self.createdAt = createdAt
        self.note = note
    }
}

/// A structural diff between two document snapshots — counts, not a
/// rendered visual diff, which is enough to answer "what changed" without
/// needing a diff-rendering UI.
public struct VersionDiff: Sendable, Equatable {
    public let pagesAdded: Int
    public let pagesRemoved: Int
    public let nodesAdded: Int
    public let nodesRemoved: Int
    public let nodesModified: Int
    public let edgesAdded: Int
    public let edgesRemoved: Int
    public let edgesModified: Int

    public var isEmpty: Bool {
        pagesAdded == 0 && pagesRemoved == 0
            && nodesAdded == 0 && nodesRemoved == 0 && nodesModified == 0
            && edgesAdded == 0 && edgesRemoved == 0 && edgesModified == 0
    }
}

public enum VersionComparator {
    public static func diff(from old: DiagramDocumentModel, to new: DiagramDocumentModel) -> VersionDiff {
        let oldPageIDs = Set(old.pages.keys)
        let newPageIDs = Set(new.pages.keys)

        var nodesAdded = 0, nodesRemoved = 0, nodesModified = 0
        var edgesAdded = 0, edgesRemoved = 0, edgesModified = 0

        for pageID in oldPageIDs.union(newPageIDs) {
            let oldNodes = old.pages[pageID]?.nodes ?? [:]
            let newNodes = new.pages[pageID]?.nodes ?? [:]
            let oldNodeIDs = Set(oldNodes.keys)
            let newNodeIDs = Set(newNodes.keys)
            nodesAdded += newNodeIDs.subtracting(oldNodeIDs).count
            nodesRemoved += oldNodeIDs.subtracting(newNodeIDs).count
            for id in oldNodeIDs.intersection(newNodeIDs) where oldNodes[id] != newNodes[id] {
                nodesModified += 1
            }

            let oldEdges = old.pages[pageID]?.edges ?? [:]
            let newEdges = new.pages[pageID]?.edges ?? [:]
            let oldEdgeIDs = Set(oldEdges.keys)
            let newEdgeIDs = Set(newEdges.keys)
            edgesAdded += newEdgeIDs.subtracting(oldEdgeIDs).count
            edgesRemoved += oldEdgeIDs.subtracting(newEdgeIDs).count
            for id in oldEdgeIDs.intersection(newEdgeIDs) where oldEdges[id] != newEdges[id] {
                edgesModified += 1
            }
        }

        return VersionDiff(
            pagesAdded: newPageIDs.subtracting(oldPageIDs).count,
            pagesRemoved: oldPageIDs.subtracting(newPageIDs).count,
            nodesAdded: nodesAdded,
            nodesRemoved: nodesRemoved,
            nodesModified: nodesModified,
            edgesAdded: edgesAdded,
            edgesRemoved: edgesRemoved,
            edgesModified: edgesModified
        )
    }
}
