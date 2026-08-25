import Foundation

public enum ShapeCategory: String, CaseIterable, Sendable {
    case general = "General"
    case flowchart = "Flowchart"
    case uml = "UML"
    case c4 = "C4"
    case erd = "ERD"
    case bpmn = "BPMN"
    case network = "Network"
    case security = "Security"

    public var id: String { rawValue }
}

public struct ShapeCatalogEntry: Identifiable, Sendable {
    public let type: ShapeType
    public let name: String
    public let category: ShapeCategory
    /// SF Symbol shown in the sidebar list row — a UI affordance, distinct
    /// from the shape's actual on-canvas geometry (`ShapeGeometry`).
    public let symbol: String

    public var id: ShapeType { type }

    public init(type: ShapeType, name: String, category: ShapeCategory, symbol: String) {
        self.type = type
        self.name = name
        self.category = category
        self.symbol = symbol
    }
}

/// The full Phase 1+2 shape catalog, grouped by `ShapeCategory` for the
/// sidebar palette (search/favorites/recently-used all filter this list
/// rather than re-deriving it). `networkFirewall`/`networkVPN` intentionally
/// appear in both Network and Security — one shape, two natural places a
/// user would look for it — rather than duplicating `ShapeType` cases for
/// the same geometry.
public enum ShapeCatalog {
    public static let general: [ShapeCatalogEntry] = [
        .init(type: .rectangle, name: "Rectangle", category: .general, symbol: "rectangle"),
        .init(type: .roundedRectangle, name: "Rounded Rectangle", category: .general, symbol: "app"),
        .init(type: .circle, name: "Circle", category: .general, symbol: "circle"),
        .init(type: .ellipse, name: "Ellipse", category: .general, symbol: "oval"),
        .init(type: .diamond, name: "Diamond", category: .general, symbol: "diamond"),
        .init(type: .triangle, name: "Triangle", category: .general, symbol: "triangle"),
        .init(type: .hexagon, name: "Hexagon", category: .general, symbol: "hexagon"),
        .init(type: .star, name: "Star", category: .general, symbol: "star"),
        .init(type: .line, name: "Line", category: .general, symbol: "line.diagonal"),
        .init(type: .arrow, name: "Arrow", category: .general, symbol: "arrow.up.right"),
        .init(type: .text, name: "Text", category: .general, symbol: "textformat"),
        .init(type: .stickyNote, name: "Sticky Note", category: .general, symbol: "note.text"),
        .init(type: .image, name: "Image", category: .general, symbol: "photo"),
        .init(type: .container, name: "Container", category: .general, symbol: "square.dashed")
    ]

    public static let flowchart: [ShapeCatalogEntry] = [
        .init(type: .flowchartStartEnd, name: "Start / End", category: .flowchart, symbol: "capsule"),
        .init(type: .flowchartProcess, name: "Process", category: .flowchart, symbol: "rectangle"),
        .init(type: .flowchartDecision, name: "Decision", category: .flowchart, symbol: "diamond"),
        .init(type: .flowchartInputOutput, name: "Input / Output", category: .flowchart, symbol: "square.on.square"),
        .init(type: .flowchartDocument, name: "Document", category: .flowchart, symbol: "doc"),
        .init(type: .flowchartDatabase, name: "Database", category: .flowchart, symbol: "cylinder"),
        .init(type: .flowchartManualProcess, name: "Manual Process", category: .flowchart, symbol: "hand.draw"),
        .init(type: .flowchartSubprocess, name: "Subprocess", category: .flowchart, symbol: "rectangle.split.3x1")
    ]

    public static let uml: [ShapeCatalogEntry] = [
        .init(type: .umlClass, name: "Class", category: .uml, symbol: "square.stack.3d.up"),
        .init(type: .umlInterface, name: "Interface", category: .uml, symbol: "circle.dotted"),
        .init(type: .umlActor, name: "Actor", category: .uml, symbol: "figure.stand"),
        .init(type: .umlUseCase, name: "Use Case", category: .uml, symbol: "oval"),
        .init(type: .umlComponent, name: "Component", category: .uml, symbol: "cube"),
        .init(type: .umlPackage, name: "Package", category: .uml, symbol: "folder"),
        .init(type: .umlSequenceLifeline, name: "Lifeline", category: .uml, symbol: "arrow.down.to.line"),
        .init(type: .umlActivity, name: "Activity", category: .uml, symbol: "app"),
        .init(type: .umlState, name: "State", category: .uml, symbol: "app.dashed"),
        .init(type: .umlDeploymentNode, name: "Deployment Node", category: .uml, symbol: "cube.transparent")
    ]

    public static let c4: [ShapeCatalogEntry] = [
        .init(type: .c4Person, name: "Person", category: .c4, symbol: "person.fill"),
        .init(type: .c4SoftwareSystem, name: "Software System", category: .c4, symbol: "square.grid.3x3.fill"),
        .init(type: .c4Container, name: "Container", category: .c4, symbol: "square.stack.fill"),
        .init(type: .c4Component, name: "Component", category: .c4, symbol: "puzzlepiece.fill"),
        .init(type: .c4ExternalSystem, name: "External System", category: .c4, symbol: "square.grid.3x3")
    ]

    public static let erd: [ShapeCatalogEntry] = [
        .init(type: .erdEntity, name: "Entity", category: .erd, symbol: "rectangle.split.3x3"),
        .init(type: .erdAttribute, name: "Attribute", category: .erd, symbol: "oval"),
        .init(type: .erdPrimaryKey, name: "Primary Key", category: .erd, symbol: "key.fill"),
        .init(type: .erdForeignKey, name: "Foreign Key", category: .erd, symbol: "key")
    ]

    public static let bpmn: [ShapeCatalogEntry] = [
        .init(type: .bpmnStartEvent, name: "Start Event", category: .bpmn, symbol: "circle"),
        .init(type: .bpmnIntermediateEvent, name: "Intermediate Event", category: .bpmn, symbol: "circle.circle"),
        .init(type: .bpmnEndEvent, name: "End Event", category: .bpmn, symbol: "circle.fill"),
        .init(type: .bpmnTask, name: "Task", category: .bpmn, symbol: "rectangle"),
        .init(type: .bpmnGateway, name: "Gateway", category: .bpmn, symbol: "diamond"),
        .init(type: .bpmnPool, name: "Pool", category: .bpmn, symbol: "rectangle.split.1x2"),
        .init(type: .bpmnLane, name: "Lane", category: .bpmn, symbol: "rectangle.split.3x1"),
        .init(type: .bpmnDataObject, name: "Data Object", category: .bpmn, symbol: "doc")
    ]

    public static let network: [ShapeCatalogEntry] = [
        .init(type: .networkRouter, name: "Router", category: .network, symbol: "point.3.connected.trianglepath.dotted"),
        .init(type: .networkSwitch, name: "Switch", category: .network, symbol: "square.grid.3x2"),
        .init(type: .networkFirewall, name: "Firewall", category: .network, symbol: "flame"),
        .init(type: .networkLoadBalancer, name: "Load Balancer", category: .network, symbol: "arrow.triangle.branch"),
        .init(type: .networkServer, name: "Server", category: .network, symbol: "server.rack"),
        .init(type: .networkNAS, name: "NAS", category: .network, symbol: "externaldrive"),
        .init(type: .networkWiFi, name: "WiFi", category: .network, symbol: "wifi"),
        .init(type: .networkVPN, name: "VPN", category: .network, symbol: "lock.shield"),
        .init(type: .networkProxy, name: "Proxy", category: .network, symbol: "arrow.left.arrow.right"),
        .init(type: .networkGateway, name: "Gateway", category: .network, symbol: "door.left.hand.open"),
        .init(type: .networkDNS, name: "DNS", category: .network, symbol: "network"),
        .init(type: .networkInternet, name: "Internet", category: .network, symbol: "globe"),
        .init(type: .networkLaptop, name: "Laptop", category: .network, symbol: "laptopcomputer"),
        .init(type: .networkDesktop, name: "Desktop", category: .network, symbol: "desktopcomputer"),
        .init(type: .networkMobile, name: "Mobile", category: .network, symbol: "iphone"),
        .init(type: .networkIoT, name: "IoT Device", category: .network, symbol: "sensor")
    ]

    public static let security: [ShapeCatalogEntry] = [
        .init(type: .securityWAF, name: "WAF", category: .security, symbol: "shield.lefthalf.filled"),
        .init(type: .networkFirewall, name: "Firewall", category: .security, symbol: "flame"),
        .init(type: .securityIDS, name: "IDS", category: .security, symbol: "eye"),
        .init(type: .securityIPS, name: "IPS", category: .security, symbol: "eye.trianglebadge.exclamationmark"),
        .init(type: .securitySIEM, name: "SIEM", category: .security, symbol: "chart.bar.doc.horizontal"),
        .init(type: .securitySOC, name: "SOC", category: .security, symbol: "person.2.badge.gearshape"),
        .init(type: .securityIAM, name: "IAM", category: .security, symbol: "person.badge.key"),
        .init(type: .securityMFA, name: "MFA", category: .security, symbol: "checkmark.shield"),
        .init(type: .securityHSM, name: "HSM", category: .security, symbol: "cpu"),
        .init(type: .securityKMS, name: "KMS", category: .security, symbol: "key.radiowaves.forward"),
        .init(type: .securityCertificateAuthority, name: "Certificate Authority", category: .security, symbol: "checkmark.seal"),
        .init(type: .securityDLP, name: "DLP", category: .security, symbol: "hand.raised"),
        .init(type: .securityZeroTrust, name: "Zero Trust", category: .security, symbol: "shield.checkerboard"),
        .init(type: .networkVPN, name: "VPN", category: .security, symbol: "lock.shield")
    ]

    public static let all: [ShapeCatalogEntry] =
        general + flowchart + uml + c4 + erd + bpmn + network + security

    public static func entries(for category: ShapeCategory) -> [ShapeCatalogEntry] {
        switch category {
        case .general: return general
        case .flowchart: return flowchart
        case .uml: return uml
        case .c4: return c4
        case .erd: return erd
        case .bpmn: return bpmn
        case .network: return network
        case .security: return security
        }
    }
}
