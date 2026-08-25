import Foundation

/// Phase 1 scope only: General + Flowchart shapes. UML/C4/ERD/BPMN/Network/
/// Security/cloud vendor shapes are later phases — not modeled here yet.
public enum ShapeType: String, Codable, Sendable, CaseIterable {
    // General
    case rectangle
    case roundedRectangle
    case circle
    case ellipse
    case diamond
    case triangle
    case hexagon
    case star
    case line
    case arrow
    case text
    case stickyNote
    case image
    case container

    // Flowchart
    case flowchartStartEnd
    case flowchartProcess
    case flowchartDecision
    case flowchartInputOutput
    case flowchartDocument
    case flowchartDatabase
    case flowchartManualProcess
    case flowchartSubprocess
}
