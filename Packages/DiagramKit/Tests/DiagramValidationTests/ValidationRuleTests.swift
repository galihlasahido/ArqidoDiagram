import XCTest
import DiagramModel
@testable import DiagramValidation

final class ValidationRuleTests: XCTestCase {
    private func makeNode(type: ShapeType, semanticType: String? = nil, owner: String? = nil, criticality: String? = nil, name: String? = nil) -> DiagramNode {
        var metadata = Metadata(semanticType: semanticType)
        metadata.owner = owner
        metadata.criticality = criticality
        return DiagramNode(
            type: type,
            position: Point2D(x: 0, y: 0),
            size: Size2D(width: 120, height: 80),
            text: name.map(TextContent.init),
            metadata: metadata
        )
    }

    private func makePage(nodes: [DiagramNode], edges: [DiagramEdge] = []) -> DiagramPage {
        var page = DiagramPage(name: "Test", order: 0)
        for node in nodes { page.nodes[node.id] = node }
        page.nodeZOrder = nodes.map(\.id)
        for edge in edges { page.edges[edge.id] = edge }
        page.edgeZOrder = edges.map(\.id)
        return page
    }

    // MARK: - Public Database

    func testPublicDatabaseRuleFlagsDirectInternetToDatabaseEdge() {
        let internet = makeNode(type: .networkInternet, name: "Internet")
        let database = makeNode(type: .flowchartDatabase, name: "Customer DB")
        let edge = DiagramEdge(source: .node(internet.id, portID: nil), target: .node(database.id, portID: nil))
        let page = makePage(nodes: [internet, database], edges: [edge])

        let issues = PublicDatabaseRule().evaluate(page)
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues.first?.severity, .error)
    }

    func testPublicDatabaseRuleIgnoresDatabaseBehindAService() {
        let internet = makeNode(type: .networkInternet, name: "Internet")
        let service = makeNode(type: .c4Container, name: "API")
        let database = makeNode(type: .flowchartDatabase, name: "Customer DB")
        let edges = [
            DiagramEdge(source: .node(internet.id, portID: nil), target: .node(service.id, portID: nil)),
            DiagramEdge(source: .node(service.id, portID: nil), target: .node(database.id, portID: nil))
        ]
        let page = makePage(nodes: [internet, service, database], edges: edges)

        XCTAssertTrue(PublicDatabaseRule().evaluate(page).isEmpty)
    }

    // MARK: - Missing Firewall / WAF

    func testMissingFirewallRuleFiresWhenNoFirewallPresent() {
        let internet = makeNode(type: .networkInternet, name: "Internet")
        let service = makeNode(type: .c4Container, name: "API")
        let edge = DiagramEdge(source: .node(internet.id, portID: nil), target: .node(service.id, portID: nil))
        let page = makePage(nodes: [internet, service], edges: [edge])

        XCTAssertEqual(MissingFirewallRule().evaluate(page).count, 1)
    }

    func testMissingFirewallRuleSilentWhenFirewallPresentAnywhere() {
        let internet = makeNode(type: .networkInternet, name: "Internet")
        let service = makeNode(type: .c4Container, name: "API")
        let firewall = makeNode(type: .networkFirewall, name: "FW")
        let edge = DiagramEdge(source: .node(internet.id, portID: nil), target: .node(service.id, portID: nil))
        let page = makePage(nodes: [internet, service, firewall], edges: [edge])

        XCTAssertTrue(MissingFirewallRule().evaluate(page).isEmpty)
    }

    func testMissingWAFRuleOnlyFlagsServiceExposure() {
        let internet = makeNode(type: .networkInternet, name: "Internet")
        let service = makeNode(type: .c4Container, name: "API")
        let edge = DiagramEdge(source: .node(internet.id, portID: nil), target: .node(service.id, portID: nil))
        let page = makePage(nodes: [internet, service], edges: [edge])

        XCTAssertEqual(MissingWAFRule().evaluate(page).count, 1)
    }

    // MARK: - Unencrypted traffic

    func testUnencryptedTrafficRuleFlagsPlainHTTPLabel() {
        let a = makeNode(type: .rectangle, name: "A")
        let b = makeNode(type: .rectangle, name: "B")
        var edge = DiagramEdge(source: .node(a.id, portID: nil), target: .node(b.id, portID: nil))
        edge.labels = [EdgeLabel(text: "http://internal-api")]
        let page = makePage(nodes: [a, b], edges: [edge])

        XCTAssertEqual(UnencryptedTrafficRule().evaluate(page).count, 1)
    }

    func testUnencryptedTrafficRuleIgnoresHTTPSLabel() {
        let a = makeNode(type: .rectangle, name: "A")
        let b = makeNode(type: .rectangle, name: "B")
        var edge = DiagramEdge(source: .node(a.id, portID: nil), target: .node(b.id, portID: nil))
        edge.labels = [EdgeLabel(text: "https://internal-api")]
        let page = makePage(nodes: [a, b], edges: [edge])

        XCTAssertTrue(UnencryptedTrafficRule().evaluate(page).isEmpty)
    }

    // MARK: - Direct service-to-database

    func testDirectServiceToDatabaseRuleFlagsCrossOwnerAccess() {
        let service = makeNode(type: .c4Container, owner: "Payments Team", name: "Checkout Service")
        let database = makeNode(type: .flowchartDatabase, owner: "Data Platform Team", name: "Analytics DB")
        let edge = DiagramEdge(source: .node(service.id, portID: nil), target: .node(database.id, portID: nil))
        let page = makePage(nodes: [service, database], edges: [edge])

        XCTAssertEqual(DirectServiceToDatabaseRule().evaluate(page).count, 1)
    }

    func testDirectServiceToDatabaseRuleIgnoresSameOwnerAccess() {
        let service = makeNode(type: .c4Container, owner: "Payments Team", name: "Checkout Service")
        let database = makeNode(type: .flowchartDatabase, owner: "Payments Team", name: "Checkout DB")
        let edge = DiagramEdge(source: .node(service.id, portID: nil), target: .node(database.id, portID: nil))
        let page = makePage(nodes: [service, database], edges: [edge])

        XCTAssertTrue(DirectServiceToDatabaseRule().evaluate(page).isEmpty)
    }

    // MARK: - Missing redundancy

    func testMissingRedundancyRuleFlagsSoleCriticalNode() {
        let database = makeNode(type: .flowchartDatabase, criticality: "High", name: "Primary DB")
        let page = makePage(nodes: [database])

        XCTAssertEqual(MissingRedundancyRule().evaluate(page).count, 1)
    }

    func testMissingRedundancyRuleSilentWithTwoInstances() {
        let a = makeNode(type: .flowchartDatabase, criticality: "High", name: "Primary DB")
        let b = makeNode(type: .flowchartDatabase, criticality: "High", name: "Replica DB")
        let page = makePage(nodes: [a, b])

        XCTAssertTrue(MissingRedundancyRule().evaluate(page).isEmpty)
    }

    func testMissingRedundancyRuleIgnoresNodesWithoutCriticalitySet() {
        let database = makeNode(type: .flowchartDatabase, name: "Primary DB")
        let page = makePage(nodes: [database])

        XCTAssertTrue(MissingRedundancyRule().evaluate(page).isEmpty)
    }

    // MARK: - Custom rules

    func testCustomRuleFlagsSubjectMissingRequiredNeighbor() {
        let rule = CustomRule(
            name: "Databases need a firewall",
            subjectType: "database",
            relatedType: "firewall",
            requireRelated: true,
            severity: .warning,
            message: ""
        )
        let database = makeNode(type: .flowchartDatabase, semanticType: "database", name: "DB")
        let page = makePage(nodes: [database])

        let issues = CustomRuleEvaluator(rule).evaluate(page)
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues.first?.severity, .warning)
    }

    func testCustomRuleSilentWhenRequiredNeighborPresent() {
        let rule = CustomRule(
            name: "Databases need a firewall",
            subjectType: "database",
            relatedType: "firewall",
            requireRelated: true,
            severity: .warning,
            message: ""
        )
        let database = makeNode(type: .flowchartDatabase, semanticType: "database", name: "DB")
        let firewall = makeNode(type: .networkFirewall, name: "FW")
        let edge = DiagramEdge(source: .node(database.id, portID: nil), target: .node(firewall.id, portID: nil))
        let page = makePage(nodes: [database, firewall], edges: [edge])

        XCTAssertTrue(CustomRuleEvaluator(rule).evaluate(page).isEmpty)
    }

    func testCustomRuleForbiddenRelationFlagsPresentEdge() {
        let rule = CustomRule(
            name: "Frontend must not talk to database",
            subjectType: "frontend",
            relatedType: "database",
            requireRelated: false,
            severity: .error,
            message: ""
        )
        let frontend = makeNode(type: .rectangle, semanticType: "frontend", name: "Web App")
        let database = makeNode(type: .flowchartDatabase, semanticType: "database", name: "DB")
        let edge = DiagramEdge(source: .node(frontend.id, portID: nil), target: .node(database.id, portID: nil))
        let page = makePage(nodes: [frontend, database], edges: [edge])

        let issues = CustomRuleEvaluator(rule).evaluate(page)
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues.first?.severity, .error)
    }

    // MARK: - Engine

    func testEngineSortsIssuesMostSevereFirst() {
        let database = makeNode(type: .flowchartDatabase, criticality: "High", name: "Sole DB")
        let a = makeNode(type: .rectangle, name: "A")
        let b = makeNode(type: .rectangle, name: "B")
        var edge = DiagramEdge(source: .node(a.id, portID: nil), target: .node(b.id, portID: nil))
        edge.labels = [EdgeLabel(text: "http://plain")]
        let page = makePage(nodes: [database, a, b], edges: [edge])

        let issues = ValidationEngine.evaluate(page)
        XCTAssertFalse(issues.isEmpty)
        for index in 1..<issues.count {
            XCTAssertTrue(issues[index - 1].severity >= issues[index].severity)
        }
    }
}
