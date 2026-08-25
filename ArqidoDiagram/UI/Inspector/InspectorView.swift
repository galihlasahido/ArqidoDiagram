import SwiftUI

/// TODO(Phase 1, build-order step 12): Position/Size/Rotation/Appearance/
/// Typography/Connector/Metadata sections bind to the current selection via
/// DiagramCommands once selection (step 7) and commands (step 8) exist.
struct InspectorView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inspector")
                .font(.headline)
            Text("Select an object to inspect its properties.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationTitle("Inspector")
    }
}
