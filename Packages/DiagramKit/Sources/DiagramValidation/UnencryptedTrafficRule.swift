import DiagramModel

/// Flags edges whose label text names an unencrypted protocol — `http://`
/// without `https`, or an explicit "unencrypted"/"plaintext"/"ftp" mention.
/// This only catches traffic the diagram author actually labeled; an edge
/// with no label carries no protocol information to check, so it's silently
/// skipped rather than assumed either way.
public struct UnencryptedTrafficRule: ValidationRule {
    public let id = "unencrypted-traffic"
    public let name = "Unencrypted Traffic"

    private static let unencryptedMarkers = ["http://", "unencrypted", "plaintext", "ftp://", "telnet"]
    private static let encryptedMarkers = ["https", "tls", "ssl", "sftp", "encrypted"]

    public init() {}

    public func evaluate(_ page: DiagramPage) -> [ValidationIssue] {
        page.edges.values.compactMap { edge in
            let labelText = edge.labels.map(\.text).joined(separator: " ").lowercased()
            guard !labelText.isEmpty else { return nil }
            guard Self.unencryptedMarkers.contains(where: { labelText.contains($0) }) else { return nil }
            guard !Self.encryptedMarkers.contains(where: { labelText.contains($0) }) else { return nil }

            return ValidationIssue(
                ruleID: id,
                ruleName: name,
                severity: .warning,
                message: "Edge labeled \"\(edge.labels.map(\.text).joined(separator: ", "))\" appears to carry unencrypted traffic.",
                edgeIDs: [edge.id]
            )
        }
    }
}
