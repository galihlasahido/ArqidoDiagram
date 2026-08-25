/// Not implemented yet. Reserved for the `NSView`-based infinite canvas
/// (`DiagramCanvasView`), `ShapeGeometry` (shared path-building used by both
/// drawing and hit-testing), `CanvasViewport` (pan/zoom transform), and
/// `SpatialGrid` (uniform-grid spatial index for hit-testing / dirty-rect
/// queries).
///
/// Depends on AppKit + Core Graphics, deliberately not SwiftUI — this keeps
/// the "not a WebView, not SwiftUI `Canvas`" requirement enforced by module
/// boundaries, and keeps the geometric core testable in plain XCTest without
/// a SwiftUI hosting environment.
///
/// Lands starting at Phase 1 build-order step 4 (static test rectangle via
/// Core Graphics).
public enum DiagramRenderingModule {}
