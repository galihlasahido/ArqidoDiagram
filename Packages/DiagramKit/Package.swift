// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DiagramKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "DiagramFoundation", targets: ["DiagramFoundation"]),
        .library(name: "DiagramModel", targets: ["DiagramModel"]),
        .library(name: "DiagramCommands", targets: ["DiagramCommands"]),
        .library(name: "DiagramPersistence", targets: ["DiagramPersistence"]),
        .library(name: "DiagramRendering", targets: ["DiagramRendering"]),
        .library(name: "DiagramInteraction", targets: ["DiagramInteraction"]),
        .library(name: "DiagramExport", targets: ["DiagramExport"])
    ],
    targets: [
        // Protocol-only seams for later phases (Layout, Validation, Import, AI)
        // plus shared foundational types. No AppKit/SwiftUI imports.
        .target(name: "DiagramFoundation"),

        // Pure scene-graph value types. Foundation-only, no AppKit/SwiftUI.
        .target(name: "DiagramModel", dependencies: ["DiagramFoundation"]),

        // Undo/redo command protocol + concrete commands. No AppKit import.
        .target(name: "DiagramCommands", dependencies: ["DiagramModel"]),

        // .diagram package read/write, schema migration.
        .target(name: "DiagramPersistence", dependencies: ["DiagramModel"]),

        // NSView-based canvas, Core Graphics drawing, spatial index. AppKit, not SwiftUI.
        .target(name: "DiagramRendering", dependencies: ["DiagramModel"]),

        // Tool state machines (select/move/resize/draw-connector/text).
        .target(
            name: "DiagramInteraction",
            dependencies: ["DiagramModel", "DiagramRendering", "DiagramCommands"]
        ),

        // PNG/SVG/PDF export adapters, reuse DiagramRendering geometry.
        .target(name: "DiagramExport", dependencies: ["DiagramModel", "DiagramRendering"]),

        .testTarget(name: "DiagramModelTests", dependencies: ["DiagramModel"]),
        .testTarget(name: "DiagramPersistenceTests", dependencies: ["DiagramPersistence"]),
        .testTarget(name: "DiagramCommandsTests", dependencies: ["DiagramCommands"]),
        .testTarget(name: "DiagramRenderingTests", dependencies: ["DiagramRendering"]),
        .testTarget(name: "DiagramExportTests", dependencies: ["DiagramExport"])
    ]
)
