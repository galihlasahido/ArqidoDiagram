import SwiftUI
import DiagramModel

/// Phase 1 scope only: General + Flowchart. UML/C4/ERD/BPMN/Network/
/// Security/cloud-vendor libraries are later phases. Clicking a shape adds
/// it to the canvas (via `ShapeInsertionRequest` -> `CanvasHostView`) at the
/// current viewport center — drag-and-drop from here onto a specific drop
/// point is a reasonable future refinement, not required for "Add shapes"
/// to be genuinely real today.
struct LibrarySidebarView: View {
    @ObservedObject var shapeInsertion: ShapeInsertionRequest

    private struct ShapeEntry: Identifiable {
        let type: ShapeType
        let name: String
        let symbol: String
        var id: ShapeType { type }
    }

    private let general: [ShapeEntry] = [
        ShapeEntry(type: .rectangle, name: "Rectangle", symbol: "rectangle"),
        ShapeEntry(type: .roundedRectangle, name: "Rounded Rectangle", symbol: "app"),
        ShapeEntry(type: .circle, name: "Circle", symbol: "circle"),
        ShapeEntry(type: .ellipse, name: "Ellipse", symbol: "oval"),
        ShapeEntry(type: .diamond, name: "Diamond", symbol: "diamond"),
        ShapeEntry(type: .triangle, name: "Triangle", symbol: "triangle"),
        ShapeEntry(type: .hexagon, name: "Hexagon", symbol: "hexagon"),
        ShapeEntry(type: .star, name: "Star", symbol: "star"),
        ShapeEntry(type: .line, name: "Line", symbol: "line.diagonal"),
        ShapeEntry(type: .arrow, name: "Arrow", symbol: "arrow.up.right"),
        ShapeEntry(type: .text, name: "Text", symbol: "textformat"),
        ShapeEntry(type: .stickyNote, name: "Sticky Note", symbol: "note.text"),
        ShapeEntry(type: .image, name: "Image", symbol: "photo"),
        ShapeEntry(type: .container, name: "Container", symbol: "square.dashed")
    ]

    private let flowchart: [ShapeEntry] = [
        ShapeEntry(type: .flowchartStartEnd, name: "Start / End", symbol: "capsule"),
        ShapeEntry(type: .flowchartProcess, name: "Process", symbol: "rectangle"),
        ShapeEntry(type: .flowchartDecision, name: "Decision", symbol: "diamond"),
        ShapeEntry(type: .flowchartInputOutput, name: "Input / Output", symbol: "square.on.square"),
        ShapeEntry(type: .flowchartDocument, name: "Document", symbol: "doc"),
        ShapeEntry(type: .flowchartDatabase, name: "Database", symbol: "cylinder"),
        ShapeEntry(type: .flowchartManualProcess, name: "Manual Process", symbol: "hand.draw"),
        ShapeEntry(type: .flowchartSubprocess, name: "Subprocess", symbol: "rectangle.split.3x1")
    ]

    var body: some View {
        List {
            Section("General") {
                ForEach(general) { entry in
                    shapeRow(entry)
                }
            }
            Section("Flowchart") {
                ForEach(flowchart) { entry in
                    shapeRow(entry)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Libraries")
    }

    private func shapeRow(_ entry: ShapeEntry) -> some View {
        Button {
            shapeInsertion.pendingType = entry.type
        } label: {
            Label(entry.name, systemImage: entry.symbol)
        }
        .buttonStyle(.plain)
        .help("Add \(entry.name) to the canvas")
    }
}
