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
        .library(name: "DiagramExport", targets: ["DiagramExport"]),
        .library(name: "DiagramLayout", targets: ["DiagramLayout"]),
        .library(name: "DiagramValidation", targets: ["DiagramValidation"]),
        .library(name: "DiagramAI", targets: ["DiagramAI"]),
        .library(name: "DiagramInterop", targets: ["DiagramInterop"])
    ],
    targets: [
        // Protocol-only seams for later phases (Layout, Validation, Import, AI)
        // plus shared foundational types. No AppKit/SwiftUI imports.
        .target(name: "DiagramFoundation"),

        // Pure scene-graph value types. Foundation-only, no AppKit/SwiftUI.
        .target(name: "DiagramModel", dependencies: ["DiagramFoundation"]),

        // Undo/redo command protocol + concrete commands. No AppKit import.
        .target(name: "DiagramCommands", dependencies: ["DiagramModel"]),

        // .diagram package read/write, schema migration, plus the two
        // app-wide (not per-document) libraries: custom components and
        // custom validation rules.
        .target(name: "DiagramPersistence", dependencies: ["DiagramModel", "DiagramValidation"]),

        // Auto Layout: an abstraction over concrete layout algorithms
        // (Hierarchical/Tree/Grid/Force-Directed/Circular/Orthogonal), each
        // a pure `DiagramPage -> DiagramPage` transform — no AppKit/SwiftUI,
        // so the algorithms are unit-testable without a canvas and the UI
        // never hard-codes layout math itself (see the spec's Auto Layout
        // requirement). Lives outside DiagramFoundation because it needs a
        // concrete `DiagramModel.DiagramPage`, and DiagramFoundation sits
        // *below* DiagramModel in the dependency graph.
        .target(name: "DiagramLayout", dependencies: ["DiagramModel"]),

        // Architecture Validation: a rules engine over DiagramPage. Same
        // rationale as DiagramLayout for living outside DiagramFoundation
        // (needs a concrete DiagramPage, which sits above DiagramFoundation
        // in the dependency graph).
        .target(name: "DiagramValidation", dependencies: ["DiagramModel"]),

        // NSView-based canvas, Core Graphics drawing, spatial index,
        // selection/move/resize/rotate interaction. AppKit, not SwiftUI.
        // Depends on DiagramCommands: interaction lives directly on
        // DiagramCanvasView rather than behind a separate tool-dispatch
        // layer (see that file's doc comment for why) — DiagramInteraction
        // remains reserved for a genuinely distinct future mode
        // (draw-connector, step 13).
        .target(name: "DiagramRendering", dependencies: ["DiagramModel", "DiagramCommands", "DiagramLayout"]),

        // Reserved: draw-connector tool state machine (step 13).
        .target(
            name: "DiagramInteraction",
            dependencies: ["DiagramModel", "DiagramRendering", "DiagramCommands"]
        ),

        // PNG/SVG/PDF export adapters, reuse DiagramRendering geometry.
        .target(name: "DiagramExport", dependencies: ["DiagramModel", "DiagramRendering"]),

        // Phase 3 "AI": Prompt -> LLM -> Structured Diagram Model ->
        // Validation -> Layout Engine -> Native Diagram Objects (the exact
        // pipeline the spec draws). `AIProvider` is the abstraction —
        // `OllamaAIProvider` (local, no network request ever leaves the
        // machine) and `RemoteAIProvider` (explicit, user-configured
        // external endpoint) are the two concrete backends. No AppKit —
        // the app target owns the ⌘K UI and Keychain-backed configuration.
        .target(name: "DiagramAI", dependencies: ["DiagramModel", "DiagramLayout", "DiagramValidation"]),

        // Phase 3/4 "Code <-> Diagram": deterministic (non-AI) parsers and
        // serializers — SQL/OpenAPI/Docker Compose/Kubernetes/Terraform/
        // Architecture-as-Code YAML importers, Mermaid/PlantUML/Graphviz/
        // YAML/SQL exporters. These are real, well-defined structured-data
        // transforms, not AI's job — reserving DiagramAI for the genuinely
        // free-form cases (natural-language prompts, arbitrary source code).
        .target(name: "DiagramInterop", dependencies: ["DiagramModel", "DiagramLayout"]),

        .testTarget(name: "DiagramModelTests", dependencies: ["DiagramModel"]),
        .testTarget(name: "DiagramPersistenceTests", dependencies: ["DiagramPersistence", "DiagramValidation"]),
        .testTarget(name: "DiagramCommandsTests", dependencies: ["DiagramCommands"]),
        .testTarget(name: "DiagramRenderingTests", dependencies: ["DiagramRendering"]),
        .testTarget(name: "DiagramExportTests", dependencies: ["DiagramExport"]),
        .testTarget(name: "DiagramLayoutTests", dependencies: ["DiagramLayout"]),
        .testTarget(name: "DiagramValidationTests", dependencies: ["DiagramValidation"]),
        .testTarget(name: "DiagramAITests", dependencies: ["DiagramAI"]),
        .testTarget(name: "DiagramInteropTests", dependencies: ["DiagramInterop"])
    ]
)
