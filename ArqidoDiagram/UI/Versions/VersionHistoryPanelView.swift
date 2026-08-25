import SwiftUI
import DiagramModel

/// Lists saved snapshots newest-first, each with its note and a live
/// "Compare with Current" diff (`VersionComparator.diff`, computed on
/// demand — versions can't drift out of sync with a cached diff since
/// there's nothing to cache). Restoring goes through
/// `DiagramDocument.restoreVersion`, which registers its own undo step.
struct VersionHistoryPanelView: View {
    @ObservedObject var document: DiagramDocument
    @ObservedObject var versionHistoryModel: VersionHistoryModel

    @State private var expandedVersionID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if document.versions.isEmpty {
                Text("No saved snapshots yet. Use File > Save Version Snapshot… to create one.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                versionList
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor)))
        .shadow(radius: 8)
        .frame(width: 420)
    }

    private var header: some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(.secondary)
            Text("Version History")
                .font(.callout.weight(.semibold))
            Spacer()
            Text("\(document.versions.count)")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Button {
                versionHistoryModel.isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(8)
    }

    private var versionList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(document.versions) { version in
                    versionRow(version)
                    Divider()
                }
            }
        }
        .frame(maxHeight: 360)
    }

    private func versionRow(_ version: DocumentVersion) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(version.note.isEmpty ? "Untitled Snapshot" : version.note)
                        .font(.callout)
                    Text(version.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Restore") {
                    document.restoreVersion(version)
                }
                .buttonStyle(.link)
            }

            let diff = VersionComparator.diff(from: version.snapshot, to: document.model)
            Button {
                expandedVersionID = expandedVersionID == version.id ? nil : version.id
            } label: {
                Label(diff.isEmpty ? "No changes since this snapshot" : "Compare with current", systemImage: "chevron.right")
                    .font(.caption)
                    .rotationEffect(.degrees(expandedVersionID == version.id ? 90 : 0))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(diff.isEmpty)

            if expandedVersionID == version.id, !diff.isEmpty {
                diffSummary(diff)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func diffSummary(_ diff: VersionDiff) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if diff.pagesAdded > 0 { Text("+ \(diff.pagesAdded) page(s)") }
            if diff.pagesRemoved > 0 { Text("− \(diff.pagesRemoved) page(s)") }
            if diff.nodesAdded > 0 { Text("+ \(diff.nodesAdded) object(s)") }
            if diff.nodesRemoved > 0 { Text("− \(diff.nodesRemoved) object(s)") }
            if diff.nodesModified > 0 { Text("~ \(diff.nodesModified) object(s) changed") }
            if diff.edgesAdded > 0 { Text("+ \(diff.edgesAdded) connector(s)") }
            if diff.edgesRemoved > 0 { Text("− \(diff.edgesRemoved) connector(s)") }
            if diff.edgesModified > 0 { Text("~ \(diff.edgesModified) connector(s) changed") }
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
        .padding(.leading, 16)
    }
}
