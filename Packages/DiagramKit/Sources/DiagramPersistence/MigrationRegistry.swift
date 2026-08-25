import Foundation
import DiagramModel

/// Schema version + migration mechanism per the spec's Document Format
/// requirement. Only schema version 1 exists today, so `V1Migrator` is a
/// no-op — the point of registering it now (rather than adding the whole
/// mechanism later) is that the migration chain is exercised by a real
/// round-trip test from day one. Future schema bumps add another migrator
/// here; `migrate(manifest:)` always walks from the manifest's version up to
/// `DiagramDocumentModel.currentSchemaVersion`.
protocol SchemaMigrator {
    var fromVersion: Int { get }
    func migrate(_ manifest: ManifestV1) throws -> ManifestV1
}

struct V1Migrator: SchemaMigrator {
    let fromVersion = 1
    func migrate(_ manifest: ManifestV1) throws -> ManifestV1 { manifest }
}

public enum MigrationError: Error, Equatable {
    case noMigratorFor(version: Int)
}

public enum MigrationRegistry {
    private static let migrators: [SchemaMigrator] = [V1Migrator()]

    public static func migrate(_ manifest: ManifestV1) throws -> ManifestV1 {
        var current = manifest
        while current.schemaVersion < DiagramDocumentModel.currentSchemaVersion {
            guard let migrator = migrators.first(where: { $0.fromVersion == current.schemaVersion }) else {
                throw MigrationError.noMigratorFor(version: current.schemaVersion)
            }
            current = try migrator.migrate(current)
            current.schemaVersion += 1
        }
        return current
    }
}
