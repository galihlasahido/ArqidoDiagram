import Foundation

/// Spec §35 "Enterprise Architecture Packs" — ready-to-use starter
/// diagrams, one per named template. Each factory closure builds a real
/// `DiagramPage` (actual nodes/edges/positions, not a picture of one) using
/// the shape/icon libraries already in this module, so "New from Template"
/// hands back something immediately editable.
public enum TemplateCategory: String, CaseIterable, Sendable {
    case enterpriseArchitecture = "Enterprise Architecture"
    case security = "Security"
    case cloud = "Cloud"
    case software = "Software"
}

public struct DiagramTemplate: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let category: TemplateCategory
    public let summary: String
    private let build: @Sendable () -> DiagramPage

    public init(id: String, name: String, category: TemplateCategory, summary: String, build: @escaping @Sendable () -> DiagramPage) {
        self.id = id
        self.name = name
        self.category = category
        self.summary = summary
        self.build = build
    }

    public func makePage() -> DiagramPage { build() }
}

public enum TemplateCatalog {
    public static let all: [DiagramTemplate] = enterpriseArchitecture + security + cloud + software

    public static func entries(for category: TemplateCategory) -> [DiagramTemplate] {
        all.filter { $0.category == category }
    }

    // MARK: - Enterprise Architecture

    public static let enterpriseArchitecture: [DiagramTemplate] = [
        DiagramTemplate(id: "system-context", name: "System Context", category: .enterpriseArchitecture, summary: "A system and the people/external systems it talks to.") {
            var b = TemplateBuilder(name: "System Context")
            b.node("Customer", type: .c4Person, x: 0, y: 120)
            b.node("Our System", type: .c4SoftwareSystem, x: 260, y: 120, w: 200)
            b.node("Payment Provider", type: .c4ExternalSystem, x: 560, y: 0, w: 200)
            b.node("Email Provider", type: .c4ExternalSystem, x: 560, y: 240, w: 200)
            b.edge("Customer", "Our System", label: "uses")
            b.edge("Our System", "Payment Provider", label: "charges via")
            b.edge("Our System", "Email Provider", label: "sends via")
            return b.page
        },
        DiagramTemplate(id: "application-architecture", name: "Application Architecture", category: .enterpriseArchitecture, summary: "Client through gateway to services and their database.") {
            var b = TemplateBuilder(name: "Application Architecture")
            b.node("Web App", type: .c4Container, x: 0, y: 120, semanticType: "service")
            b.node("API Gateway", type: .networkGateway, x: 260, y: 120)
            b.node("Orders Service", type: .c4Container, x: 520, y: 0, semanticType: "service")
            b.node("Users Service", type: .c4Container, x: 520, y: 240, semanticType: "service")
            b.node("Database", type: .flowchartDatabase, x: 800, y: 120, semanticType: "database")
            b.edge("Web App", "API Gateway")
            b.edge("API Gateway", "Orders Service")
            b.edge("API Gateway", "Users Service")
            b.edge("Orders Service", "Database")
            b.edge("Users Service", "Database")
            return b.page
        },
        DiagramTemplate(id: "integration-architecture", name: "Integration Architecture", category: .enterpriseArchitecture, summary: "Two services decoupled through a message queue.") {
            var b = TemplateBuilder(name: "Integration Architecture")
            b.node("Order Service", type: .c4Container, x: 0, y: 120, semanticType: "service")
            b.node("Message Queue", type: .networkServer, x: 280, y: 120, semanticType: "queue")
            b.node("Fulfillment Service", type: .c4Container, x: 560, y: 120, semanticType: "service")
            b.node("API Gateway", type: .networkGateway, x: 280, y: 320)
            b.node("Partner System", type: .c4ExternalSystem, x: 560, y: 320, w: 200)
            b.edge("Order Service", "Message Queue", label: "publishes")
            b.edge("Message Queue", "Fulfillment Service", label: "consumes")
            b.edge("API Gateway", "Partner System", label: "integrates")
            return b.page
        },
        DiagramTemplate(id: "data-architecture", name: "Data Architecture", category: .enterpriseArchitecture, summary: "Source systems through a pipeline into a warehouse and BI.") {
            var b = TemplateBuilder(name: "Data Architecture")
            b.node("Source System A", type: .c4ExternalSystem, x: 0, y: 0, w: 180)
            b.node("Source System B", type: .c4ExternalSystem, x: 0, y: 200, w: 180)
            b.node("ETL Pipeline", type: .flowchartProcess, x: 280, y: 100)
            b.node("Data Warehouse", type: .flowchartDatabase, x: 540, y: 100, semanticType: "database")
            b.node("BI / Analytics", type: .c4Container, x: 800, y: 100)
            b.edge("Source System A", "ETL Pipeline")
            b.edge("Source System B", "ETL Pipeline")
            b.edge("ETL Pipeline", "Data Warehouse")
            b.edge("Data Warehouse", "BI / Analytics")
            return b.page
        },
        DiagramTemplate(id: "infrastructure-architecture", name: "Infrastructure Architecture", category: .enterpriseArchitecture, summary: "Firewall-fronted load-balanced app tier over a database.") {
            var b = TemplateBuilder(name: "Infrastructure Architecture")
            b.node("Internet", type: .networkInternet, x: 0, y: 120)
            b.node("Firewall", type: .networkFirewall, x: 260, y: 120)
            b.node("Load Balancer", type: .networkLoadBalancer, x: 520, y: 120)
            b.node("App Server 1", type: .networkServer, x: 780, y: 0, semanticType: "service")
            b.node("App Server 2", type: .networkServer, x: 780, y: 240, semanticType: "service")
            b.node("Database", type: .networkNAS, x: 1040, y: 120, semanticType: "database")
            b.edge("Internet", "Firewall")
            b.edge("Firewall", "Load Balancer")
            b.edge("Load Balancer", "App Server 1")
            b.edge("Load Balancer", "App Server 2")
            b.edge("App Server 1", "Database")
            b.edge("App Server 2", "Database")
            return b.page
        },
        DiagramTemplate(id: "security-architecture", name: "Security Architecture", category: .enterpriseArchitecture, summary: "Defense in depth from the internet to the database.") {
            var b = TemplateBuilder(name: "Security Architecture")
            b.node("Internet", type: .networkInternet, x: 0, y: 140)
            b.node("WAF", type: .securityWAF, x: 240, y: 140)
            b.node("Firewall", type: .networkFirewall, x: 480, y: 140)
            b.node("Application", type: .c4Container, x: 720, y: 140, semanticType: "service")
            b.node("Database", type: .flowchartDatabase, x: 960, y: 140, semanticType: "database")
            b.node("IAM", type: .securityIAM, x: 720, y: 340)
            b.node("SIEM", type: .securitySIEM, x: 960, y: 340)
            b.edge("Internet", "WAF")
            b.edge("WAF", "Firewall")
            b.edge("Firewall", "Application")
            b.edge("Application", "Database")
            b.edge("IAM", "Application", label: "authenticates")
            b.edge("Application", "SIEM", label: "logs to")
            return b.page
        }
    ]

    // MARK: - Security

    public static let security: [DiagramTemplate] = [
        DiagramTemplate(id: "zero-trust", name: "Zero Trust", category: .security, summary: "Every request is authenticated and authorized at the boundary.") {
            var b = TemplateBuilder(name: "Zero Trust")
            b.node("User", type: .c4Person, x: 0, y: 120)
            b.node("IAM", type: .securityIAM, x: 240, y: 0)
            b.node("MFA", type: .securityMFA, x: 240, y: 240)
            b.node("Policy Enforcement Point", type: .securityZeroTrust, x: 500, y: 120, w: 200)
            b.node("Protected Resource", type: .c4Container, x: 780, y: 120, semanticType: "service")
            b.edge("User", "IAM", label: "authenticates")
            b.edge("User", "MFA", label: "verifies")
            b.edge("IAM", "Policy Enforcement Point")
            b.edge("MFA", "Policy Enforcement Point")
            b.edge("Policy Enforcement Point", "Protected Resource", label: "authorizes each request")
            return b.page
        },
        DiagramTemplate(id: "soc", name: "SOC", category: .security, summary: "Security operations center triaging signals into response.") {
            var b = TemplateBuilder(name: "SOC")
            b.node("Log Sources", type: .flowchartDocument, x: 0, y: 120)
            b.node("SIEM", type: .securitySIEM, x: 260, y: 120)
            b.node("SOC Analysts", type: .securitySOC, x: 520, y: 120)
            b.node("Incident Response", type: .bpmnTask, x: 780, y: 120)
            b.edge("Log Sources", "SIEM", label: "ships logs")
            b.edge("SIEM", "SOC Analysts", label: "alerts")
            b.edge("SOC Analysts", "Incident Response", label: "triages")
            return b.page
        },
        DiagramTemplate(id: "siem", name: "SIEM", category: .security, summary: "Multiple log sources centralized into one SIEM with alerting.") {
            var b = TemplateBuilder(name: "SIEM")
            b.node("App Logs", type: .flowchartDocument, x: 0, y: 0)
            b.node("Network Logs", type: .flowchartDocument, x: 0, y: 150)
            b.node("Cloud Logs", type: .flowchartDocument, x: 0, y: 300)
            b.node("SIEM", type: .securitySIEM, x: 300, y: 150)
            b.node("Alerting", type: .bpmnIntermediateEvent, x: 560, y: 150)
            b.edge("App Logs", "SIEM")
            b.edge("Network Logs", "SIEM")
            b.edge("Cloud Logs", "SIEM")
            b.edge("SIEM", "Alerting")
            return b.page
        },
        DiagramTemplate(id: "iam", name: "IAM", category: .security, summary: "Identity, MFA, and access to an application.") {
            var b = TemplateBuilder(name: "IAM")
            b.node("User", type: .c4Person, x: 0, y: 120)
            b.node("Identity Provider", type: .securityIAM, x: 260, y: 120)
            b.node("MFA", type: .securityMFA, x: 260, y: 320)
            b.node("Application", type: .c4Container, x: 520, y: 120, semanticType: "service")
            b.edge("User", "Identity Provider", label: "signs in")
            b.edge("Identity Provider", "MFA", label: "challenges")
            b.edge("Identity Provider", "Application", label: "issues token")
            return b.page
        },
        DiagramTemplate(id: "pci-dss", name: "PCI DSS Architecture", category: .security, summary: "Cardholder data environment isolated behind firewall and WAF.") {
            var b = TemplateBuilder(name: "PCI DSS Architecture")
            b.node("Internet", type: .networkInternet, x: 0, y: 140)
            b.node("WAF", type: .securityWAF, x: 240, y: 140)
            b.node("Firewall", type: .networkFirewall, x: 480, y: 140)
            b.node("Payment Service", type: .c4Container, x: 720, y: 140, semanticType: "service")
            b.node("Cardholder Data Environment", type: .container, x: 960, y: 60, w: 220, h: 220, semanticType: "database")
            b.node("HSM", type: .securityHSM, x: 960, y: 320)
            b.edge("Internet", "WAF")
            b.edge("WAF", "Firewall")
            b.edge("Firewall", "Payment Service")
            b.edge("Payment Service", "Cardholder Data Environment")
            b.edge("Payment Service", "HSM", label: "encrypts via")
            return b.page
        },
        DiagramTemplate(id: "network-segmentation", name: "Network Segmentation", category: .security, summary: "DMZ, internal, and restricted zones separated by firewalls.") {
            var b = TemplateBuilder(name: "Network Segmentation")
            b.node("Internet", type: .networkInternet, x: 0, y: 140)
            b.node("Firewall (Edge)", type: .networkFirewall, x: 240, y: 140)
            b.node("DMZ", type: .container, x: 480, y: 140, w: 180)
            b.node("Firewall (Internal)", type: .networkFirewall, x: 740, y: 140)
            b.node("Internal Zone", type: .container, x: 980, y: 40, w: 180)
            b.node("Firewall (Restricted)", type: .networkFirewall, x: 740, y: 340)
            b.node("Restricted Zone", type: .container, x: 980, y: 340, w: 180)
            b.edge("Internet", "Firewall (Edge)")
            b.edge("Firewall (Edge)", "DMZ")
            b.edge("DMZ", "Firewall (Internal)")
            b.edge("Firewall (Internal)", "Internal Zone")
            b.edge("Internal Zone", "Firewall (Restricted)")
            b.edge("Firewall (Restricted)", "Restricted Zone")
            return b.page
        }
    ]

    // MARK: - Cloud

    public static let cloud: [DiagramTemplate] = [
        DiagramTemplate(id: "aws-reference", name: "AWS", category: .cloud, summary: "A load-balanced compute tier over storage and a database.") {
            cloudReferenceArchitecture(name: "AWS Reference Architecture", compute: .awsCompute, storage: .awsStorage, database: .awsDatabase)
        },
        DiagramTemplate(id: "azure-reference", name: "Azure", category: .cloud, summary: "A load-balanced compute tier over storage and a database.") {
            cloudReferenceArchitecture(name: "Azure Reference Architecture", compute: .azureCompute, storage: .azureStorage, database: .azureDatabase)
        },
        DiagramTemplate(id: "gcp-reference", name: "Google Cloud", category: .cloud, summary: "A load-balanced compute tier over storage and a database.") {
            cloudReferenceArchitecture(name: "Google Cloud Reference Architecture", compute: .gcpCompute, storage: .gcpStorage, database: .gcpDatabase)
        },
        DiagramTemplate(id: "kubernetes-reference", name: "Kubernetes", category: .cloud, summary: "Ingress through a service to a deployment's pods, configured via a ConfigMap.") {
            var b = TemplateBuilder(name: "Kubernetes Reference Architecture")
            b.node("Ingress", type: .roundedRectangle, x: 0, y: 140, icon: .kubernetesIngress)
            b.node("Service", type: .roundedRectangle, x: 260, y: 140, icon: .kubernetesService)
            b.node("Deployment", type: .roundedRectangle, x: 520, y: 140, icon: .kubernetesDeployment)
            b.node("Pod 1", type: .roundedRectangle, x: 780, y: 40, icon: .kubernetesPod)
            b.node("Pod 2", type: .roundedRectangle, x: 780, y: 240, icon: .kubernetesPod)
            b.node("ConfigMap", type: .roundedRectangle, x: 520, y: 340, icon: .kubernetesConfigMap)
            b.node("Cluster", type: .roundedRectangle, x: 1040, y: 140, icon: .kubernetesCluster)
            b.edge("Ingress", "Service")
            b.edge("Service", "Deployment")
            b.edge("Deployment", "Pod 1")
            b.edge("Deployment", "Pod 2")
            b.edge("ConfigMap", "Deployment", label: "configures")
            b.edge("Pod 1", "Cluster")
            b.edge("Pod 2", "Cluster")
            return b.page
        },
        DiagramTemplate(id: "docker-reference", name: "Docker", category: .cloud, summary: "Containerized services on a shared host talking to a database.") {
            var b = TemplateBuilder(name: "Docker Reference Architecture")
            b.node("Docker Host", type: .container, x: 0, y: 0, w: 620, h: 260)
            b.node("Web Container", type: .roundedRectangle, x: 40, y: 100, semanticType: "service")
            b.node("API Container", type: .roundedRectangle, x: 280, y: 100, semanticType: "service")
            b.node("Worker Container", type: .roundedRectangle, x: 520, y: 100, w: 60, semanticType: "service")
            b.node("Database", type: .flowchartDatabase, x: 780, y: 100, semanticType: "database")
            b.edge("Web Container", "API Container")
            b.edge("API Container", "Worker Container")
            b.edge("API Container", "Database")
            return b.page
        }
    ]

    // MARK: - Software

    public static let software: [DiagramTemplate] = [
        DiagramTemplate(id: "c4-starter", name: "C4", category: .software, summary: "A Person, Software System, and its Containers.") {
            var b = TemplateBuilder(name: "C4 Model")
            b.node("User", type: .c4Person, x: 0, y: 140)
            b.node("Software System", type: .c4SoftwareSystem, x: 260, y: 140, w: 200)
            b.node("Web Application", type: .c4Container, x: 560, y: 40)
            b.node("API", type: .c4Container, x: 560, y: 240)
            b.node("Database", type: .c4Container, x: 820, y: 140)
            b.edge("User", "Software System", label: "uses")
            b.edge("Software System", "Web Application")
            b.edge("Software System", "API")
            b.edge("API", "Database", label: "reads/writes")
            return b.page
        },
        DiagramTemplate(id: "uml-starter", name: "UML", category: .software, summary: "A class diagram skeleton with an actor and use case.") {
            var b = TemplateBuilder(name: "UML")
            b.node("Actor", type: .umlActor, x: 0, y: 140)
            b.node("Place Order", type: .umlUseCase, x: 240, y: 140)
            b.node("Order", type: .umlClass, x: 520, y: 40)
            b.node("OrderService", type: .umlComponent, x: 520, y: 240)
            b.node("IOrderRepository", type: .umlInterface, x: 800, y: 240)
            b.edge("Actor", "Place Order")
            b.edge("Place Order", "Order", label: "creates")
            b.edge("OrderService", "Order", label: "manages")
            b.edge("OrderService", "IOrderRepository", label: "depends on")
            return b.page
        },
        DiagramTemplate(id: "microservices", name: "Microservices", category: .software, summary: "A gateway routing to independently-owned services, each with its own database.") {
            var b = TemplateBuilder(name: "Microservices")
            b.node("API Gateway", type: .networkGateway, x: 0, y: 200)
            b.node("Orders Service", type: .c4Container, x: 320, y: 0, semanticType: "service")
            b.node("Orders DB", type: .flowchartDatabase, x: 620, y: 0, semanticType: "database")
            b.node("Users Service", type: .c4Container, x: 320, y: 200, semanticType: "service")
            b.node("Users DB", type: .flowchartDatabase, x: 620, y: 200, semanticType: "database")
            b.node("Inventory Service", type: .c4Container, x: 320, y: 400, semanticType: "service")
            b.node("Inventory DB", type: .flowchartDatabase, x: 620, y: 400, semanticType: "database")
            b.edge("API Gateway", "Orders Service")
            b.edge("API Gateway", "Users Service")
            b.edge("API Gateway", "Inventory Service")
            b.edge("Orders Service", "Orders DB")
            b.edge("Users Service", "Users DB")
            b.edge("Inventory Service", "Inventory DB")
            return b.page
        },
        DiagramTemplate(id: "event-driven", name: "Event-Driven Architecture", category: .software, summary: "Producers and consumers decoupled through an event bus.") {
            var b = TemplateBuilder(name: "Event-Driven Architecture")
            b.node("Order Service", type: .c4Container, x: 0, y: 0, semanticType: "service")
            b.node("Inventory Service", type: .c4Container, x: 0, y: 260, semanticType: "service")
            b.node("Event Bus", type: .networkServer, x: 320, y: 130, semanticType: "queue")
            b.node("Notification Service", type: .c4Container, x: 640, y: 0, semanticType: "service")
            b.node("Analytics Service", type: .c4Container, x: 640, y: 260, semanticType: "service")
            b.edge("Order Service", "Event Bus", label: "publishes")
            b.edge("Inventory Service", "Event Bus", label: "publishes")
            b.edge("Event Bus", "Notification Service", label: "consumes")
            b.edge("Event Bus", "Analytics Service", label: "consumes")
            return b.page
        },
        DiagramTemplate(id: "api-architecture", name: "API Architecture", category: .software, summary: "Client through a gateway to authenticated, versioned backend APIs.") {
            var b = TemplateBuilder(name: "API Architecture")
            b.node("Client App", type: .c4Person, x: 0, y: 160)
            b.node("API Gateway", type: .networkGateway, x: 280, y: 160)
            b.node("Auth Service", type: .securityIAM, x: 560, y: 0)
            b.node("Orders API", type: .c4Container, x: 560, y: 160, semanticType: "service")
            b.node("Users API", type: .c4Container, x: 560, y: 320, semanticType: "service")
            b.edge("Client App", "API Gateway")
            b.edge("API Gateway", "Auth Service", label: "authenticates")
            b.edge("API Gateway", "Orders API")
            b.edge("API Gateway", "Users API")
            return b.page
        },
        DiagramTemplate(id: "mindmap", name: "Mindmap", category: .software, summary: "A central idea radiating out to branches — brainstorm structure, not architecture.") {
            var b = TemplateBuilder(name: "Mindmap")
            b.node("Central Idea", type: .circle, x: 400, y: 240, w: 180, h: 120)
            b.node("Branch 1", type: .roundedRectangle, x: 0, y: 0, w: 180, h: 80)
            b.node("Branch 2", type: .roundedRectangle, x: 0, y: 200, w: 180, h: 80)
            b.node("Branch 3", type: .roundedRectangle, x: 0, y: 400, w: 180, h: 80)
            b.node("Branch 4", type: .roundedRectangle, x: 820, y: 0, w: 180, h: 80)
            b.node("Branch 5", type: .roundedRectangle, x: 820, y: 200, w: 180, h: 80)
            b.node("Branch 6", type: .roundedRectangle, x: 820, y: 400, w: 180, h: 80)
            for branch in ["Branch 1", "Branch 2", "Branch 3", "Branch 4", "Branch 5", "Branch 6"] {
                b.edge("Central Idea", branch)
            }
            return b.page
        }
    ]

    private static func cloudReferenceArchitecture(name: String, compute: TechIconType, storage: TechIconType, database: TechIconType) -> DiagramPage {
        var b = TemplateBuilder(name: name)
        b.node("Internet", type: .networkInternet, x: 0, y: 140)
        b.node("Load Balancer", type: .networkLoadBalancer, x: 260, y: 140)
        b.node("Compute", type: .roundedRectangle, x: 520, y: 140, icon: compute, semanticType: "service")
        b.node("Database", type: .roundedRectangle, x: 780, y: 40, icon: database, semanticType: "database")
        b.node("Storage", type: .roundedRectangle, x: 780, y: 240, icon: storage)
        b.edge("Internet", "Load Balancer")
        b.edge("Load Balancer", "Compute")
        b.edge("Compute", "Database")
        b.edge("Compute", "Storage")
        return b.page
    }
}

/// A tiny internal DSL so each template's node/edge layout reads as a short
/// list of calls instead of hand-assembled dictionaries — nodes are looked
/// up by their label when wiring edges, since templates are always written
/// with distinct human-readable labels.
private struct TemplateBuilder {
    var page: DiagramPage
    private var idsByLabel: [String: NodeID] = [:]

    init(name: String) {
        page = DiagramPage(name: name, order: 0)
    }

    mutating func node(
        _ label: String,
        type: ShapeType,
        x: Double,
        y: Double,
        w: Double = 160,
        h: Double = 90,
        icon: TechIconType? = nil,
        semanticType: String? = nil
    ) {
        let node = DiagramNode(
            type: type,
            position: Point2D(x: x, y: y),
            size: Size2D(width: w, height: h),
            text: TextContent(string: label),
            metadata: Metadata(semanticType: semanticType),
            iconType: icon
        )
        page.nodes[node.id] = node
        page.nodeZOrder.append(node.id)
        idsByLabel[label] = node.id
    }

    mutating func edge(_ from: String, _ to: String, label: String? = nil) {
        guard let sourceID = idsByLabel[from], let targetID = idsByLabel[to] else { return }
        var edge = DiagramEdge(source: .node(sourceID, portID: nil), target: .node(targetID, portID: nil))
        if let label { edge.labels = [EdgeLabel(text: label)] }
        page.edges[edge.id] = edge
        page.edgeZOrder.append(edge.id)
    }
}
