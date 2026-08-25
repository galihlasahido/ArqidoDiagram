import Foundation

/// One flat, closed enum — not a plugin/dynamic shape system — covers every
/// Phase 1+2 shape. Given the actual requirement (a rich *built-in*
/// catalog, not user-defined primitive geometry — "Custom Components" lets
/// users save existing shape *combinations*, not new geometry), a plugin
/// architecture would be speculative complexity with no real consumer.
/// `ShapeCatalog` (this module) layers category/display-name/search
/// metadata on top without needing the type itself to carry any of that.
public enum ShapeType: String, Codable, Sendable, CaseIterable {
    // MARK: General
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

    // MARK: Flowchart
    case flowchartStartEnd
    case flowchartProcess
    case flowchartDecision
    case flowchartInputOutput
    case flowchartDocument
    case flowchartDatabase
    case flowchartManualProcess
    case flowchartSubprocess

    // MARK: UML
    case umlClass
    case umlInterface
    case umlActor
    case umlUseCase
    case umlComponent
    case umlPackage
    case umlSequenceLifeline
    case umlActivity
    case umlState
    case umlDeploymentNode

    // MARK: C4
    case c4Person
    case c4SoftwareSystem
    case c4Container
    case c4Component
    case c4ExternalSystem

    // MARK: ERD
    case erdEntity
    case erdAttribute
    case erdPrimaryKey
    case erdForeignKey

    // MARK: BPMN
    case bpmnStartEvent
    case bpmnIntermediateEvent
    case bpmnEndEvent
    case bpmnTask
    case bpmnGateway
    case bpmnPool
    case bpmnLane
    case bpmnDataObject

    // MARK: Network
    case networkRouter
    case networkSwitch
    case networkFirewall
    case networkLoadBalancer
    case networkServer
    case networkNAS
    case networkWiFi
    case networkVPN
    case networkProxy
    case networkGateway
    case networkDNS
    case networkInternet
    case networkLaptop
    case networkDesktop
    case networkMobile
    case networkIoT

    // MARK: Security
    case securityWAF
    case securityIDS
    case securityIPS
    case securitySIEM
    case securitySOC
    case securityIAM
    case securityMFA
    case securityHSM
    case securityKMS
    case securityCertificateAuthority
    case securityDLP
    case securityZeroTrust
}
