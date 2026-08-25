import SwiftUI
import DiagramModel
import DiagramRendering

/// Position/Size/Rotation are only meaningful for exactly one node at a
/// time (setting them identically across a multi-selection would collapse
/// the nodes together), so they only appear then. Appearance/Metadata apply
/// uniformly across however many nodes are selected via
/// `DiagramCanvasView.updateSelectedNodes`, the same single Command entry
/// point canvas-driven edits use — Inspector edits are undoable exactly the
/// same way.
///
/// TODO: Connector section — deferred until edges are individually
/// selectable (see DiagramCanvasView's edge-hit-testing TODO).
struct InspectorView: View {
    @ObservedObject var document: DiagramDocument
    @ObservedObject var selection: SelectionModel
    @ObservedObject var bridge: InspectorBridge

    /// Scans every page rather than threading an `activePageID` through —
    /// `selection.selectedNodeIDs` is already pruned to whichever page is
    /// actually loaded on the canvas (see `DiagramCanvasView.loadPage`), so
    /// this always resolves to the right page's nodes with no extra state.
    private var selectedNodes: [DiagramNode] {
        document.model.pages.values.flatMap { page in
            selection.selectedNodeIDs.compactMap { page.nodes[$0] }
        }
    }

    var body: some View {
        Group {
            if selectedNodes.count == 1 {
                singleSelectionForm(selectedNodes[0])
            } else if selectedNodes.count > 1 {
                multiSelectionForm(selectedNodes)
            } else {
                emptyState
            }
        }
        // Without an explicit top alignment here, the `NavigationSplitView`
        // detail column centers whatever it's given vertically whenever the
        // Form's content is shorter than the column — this is what was
        // producing the large empty gap above "Position" (and a matching
        // one below "Tags") instead of the form simply starting at the top.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("Inspector")
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inspector")
                .font(.headline)
            Text("Select an object to inspect its properties.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Single selection

    private func singleSelectionForm(_ node: DiagramNode) -> some View {
        Form {
            Section("Position") {
                TextField("X", value: doubleBinding(\.position.x), format: .number)
                TextField("Y", value: doubleBinding(\.position.y), format: .number)
            }
            Section("Size") {
                TextField("Width", value: doubleBinding(\.size.width), format: .number)
                TextField("Height", value: doubleBinding(\.size.height), format: .number)
            }
            Section("Rotation") {
                TextField("Degrees", value: degreesBinding, format: .number)
            }
            appearanceSection
            iconSection
            typographySection
            metadataSection
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Multi-selection

    private func multiSelectionForm(_ nodes: [DiagramNode]) -> some View {
        Form {
            Section {
                Text("\(nodes.count) objects selected")
                    .foregroundStyle(.secondary)
            }
            appearanceSection
            metadataSection
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Shared sections (apply to every selected node)

    private var appearanceSection: some View {
        Section("Appearance") {
            ColorPicker("Fill", selection: colorBinding(\.fill))
            ColorPicker("Border", selection: colorBinding(\.strokeColor))
            Slider(value: opacityBinding, in: 0...1) { Text("Opacity") }
        }
    }

    /// Single-selection only — an icon badge is a per-node decision, unlike
    /// Appearance/Metadata which apply uniformly across a multi-selection.
    private var iconSection: some View {
        Section("Icon") {
            Picker("Technology Icon", selection: iconTypeBinding) {
                Text("None").tag(TechIconType?.none)
                ForEach(IconPack.allCases, id: \.self) { pack in
                    ForEach(TechIconCatalog.entries(for: pack)) { entry in
                        Text("\(pack.rawValue) — \(entry.name)").tag(TechIconType?.some(entry.id))
                    }
                }
            }
        }
    }

    private var iconTypeBinding: Binding<TechIconType?> {
        Binding(
            get: { selectedNodes.first?.iconType },
            set: { newValue in
                bridge.canvasView?.updateSelectedNodes(actionName: "Set Icon") { $0.iconType = newValue }
            }
        )
    }

    private var typographySection: some View {
        Section("Typography") {
            TextField("Font Size", value: fontSizeBinding, format: .number)
        }
    }

    @ViewBuilder
    private var metadataSection: some View {
        Section("Metadata") {
            TextField("Type", text: metadataBinding(\.semanticType))
                .help("A machine-readable architectural role — e.g. service, database, gateway, firewall, queue. Used by Architecture Validation rules.")
            TextField("Technology", text: metadataBinding(\.technology))
            TextField("Owner", text: metadataBinding(\.owner))
            TextField("Environment", text: metadataBinding(\.environment))
            TextField("Criticality", text: metadataBinding(\.criticality))
            TextField("Description", text: metadataBinding(\.notes))
        }
        Section("Tags") {
            TextField("Tags", text: tagsBinding)
                .help("Comma-separated tags.")
        }
    }

    // MARK: - Bindings

    /// Only meaningful with exactly one node selected — reads/writes
    /// `selectedNodes[0]` directly rather than looping, since
    /// `updateSelectedNodes` would otherwise (harmlessly, but pointlessly)
    /// apply the same absolute value to every selected node.
    private func doubleBinding(_ keyPath: WritableKeyPath<DiagramNode, Double>) -> Binding<Double> {
        Binding(
            get: { selectedNodes.first?[keyPath: keyPath] ?? 0 },
            set: { newValue in
                bridge.canvasView?.updateSelectedNodes(actionName: "Set Property") { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    private var degreesBinding: Binding<Double> {
        Binding(
            get: { (selectedNodes.first?.rotation ?? 0) * 180 / .pi },
            set: { degrees in
                let radians = degrees * .pi / 180
                bridge.canvasView?.updateSelectedNodes(actionName: "Rotate") { $0.rotation = radians }
            }
        )
    }

    private var opacityBinding: Binding<Double> {
        Binding(
            get: { selectedNodes.first?.style.opacity ?? 1 },
            set: { newValue in
                bridge.canvasView?.updateSelectedNodes(actionName: "Set Opacity") { $0.style.opacity = newValue }
            }
        )
    }

    private var fontSizeBinding: Binding<Double> {
        Binding(
            get: { selectedNodes.first?.style.font?.size ?? 13 },
            set: { newValue in
                bridge.canvasView?.updateSelectedNodes(actionName: "Set Font Size") { node in
                    var font = node.style.font ?? FontStyle()
                    font.size = newValue
                    node.style.font = font
                }
            }
        )
    }

    private func colorBinding(_ keyPath: WritableKeyPath<DiagramModel.ShapeStyle, ColorRef?>) -> Binding<Color> {
        Binding(
            get: {
                guard let ref = selectedNodes.first?.style[keyPath: keyPath] else { return Color(nsColor: .quaternaryLabelColor) }
                return Color(nsColor: NSColor(ref))
            },
            set: { newColor in
                let ref = ColorRef(nsColor: NSColor(newColor))
                bridge.canvasView?.updateSelectedNodes(actionName: "Set Color") { $0.style[keyPath: keyPath] = ref }
            }
        )
    }

    private var tagsBinding: Binding<String> {
        Binding(
            get: { selectedNodes.first?.metadata.tags.joined(separator: ", ") ?? "" },
            set: { newValue in
                let tags = newValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                bridge.canvasView?.updateSelectedNodes(actionName: "Set Tags") { $0.metadata.tags = tags }
            }
        )
    }

    private func metadataBinding(_ keyPath: WritableKeyPath<Metadata, String?>) -> Binding<String> {
        Binding(
            get: { selectedNodes.first?.metadata[keyPath: keyPath] ?? "" },
            set: { newValue in
                let value = newValue.isEmpty ? nil : newValue
                bridge.canvasView?.updateSelectedNodes(actionName: "Set Metadata") { $0.metadata[keyPath: keyPath] = value }
            }
        )
    }
}
