import XCTest
import DiagramModel
import DiagramLayout
@testable import DiagramAI

private struct StubAIProvider: AIProvider {
    let displayName = "Stub"
    let response: String
    func complete(system: String, user: String, maxTokens: Int) async throws -> String { response }
}

private struct ThrowingAIProvider: AIProvider {
    let displayName = "Throwing"
    func complete(system: String, user: String, maxTokens: Int) async throws -> String {
        throw AIProviderError.requestFailed("offline")
    }
}

final class AIArchitectTests: XCTestCase {
    func testGenerateDiagramMaterializesRealNodesAndEdges() async throws {
        let json = """
        {"nodes":[{"id":"gw","label":"API Gateway","type":"gateway"},
                   {"id":"svc","label":"Payment Service","type":"service"},
                   {"id":"db","label":"PostgreSQL","type":"database"}],
         "edges":[{"from":"gw","to":"svc"},{"from":"svc","to":"db","label":"reads/writes"}]}
        """
        let architect = AIArchitect(provider: StubAIProvider(response: json))
        let result = try await architect.generateDiagram(prompt: "payment architecture")

        XCTAssertEqual(result.nodes.count, 3)
        XCTAssertEqual(result.edges.count, 2)
        XCTAssertEqual(result.nodes.map(\.text?.string), ["API Gateway", "Payment Service", "PostgreSQL"])
        XCTAssertEqual(result.nodes.first?.type, .networkGateway)
        XCTAssertEqual(result.nodes[2].type, .flowchartDatabase)
        XCTAssertEqual(result.nodes.first?.metadata.semanticType, "gateway")
    }

    func testGenerateDiagramPositionsNodesViaTheGivenLayoutEngine() async throws {
        let json = """
        {"nodes":[{"id":"a","label":"A","type":"service"},{"id":"b","label":"B","type":"service"}],
         "edges":[{"from":"a","to":"b"}]}
        """
        let architect = AIArchitect(provider: StubAIProvider(response: json))
        let result = try await architect.generateDiagram(prompt: "two services", layout: GridLayoutEngine())

        // Grid layout places nodes at distinct cells, not all at (0,0).
        let positions = Set(result.nodes.map { "\($0.position.x),\($0.position.y)" })
        XCTAssertEqual(positions.count, 2)
    }

    func testResponseWrappedInMarkdownFenceStillParses() async throws {
        let fenced = """
        Here you go:
        ```json
        {"nodes":[{"id":"a","label":"A","type":"service"}],"edges":[]}
        ```
        """
        let architect = AIArchitect(provider: StubAIProvider(response: fenced))
        let result = try await architect.generateDiagram(prompt: "one node")
        XCTAssertEqual(result.nodes.count, 1)
    }

    func testEdgeReferencingUnknownNodeIsDropped() async throws {
        let json = """
        {"nodes":[{"id":"a","label":"A","type":"service"}],
         "edges":[{"from":"a","to":"does-not-exist"}]}
        """
        let architect = AIArchitect(provider: StubAIProvider(response: json))
        let result = try await architect.generateDiagram(prompt: "one node, bad edge")
        XCTAssertEqual(result.nodes.count, 1)
        XCTAssertTrue(result.edges.isEmpty)
    }

    func testMalformedResponseThrowsRatherThanCrashing() async {
        let architect = AIArchitect(provider: StubAIProvider(response: "I'm sorry, I can't help with that."))
        do {
            _ = try await architect.generateDiagram(prompt: "anything")
            XCTFail("expected a parse error")
        } catch let AIArchitectError.couldNotParseResponse(raw) {
            XCTAssertTrue(raw.contains("sorry"))
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }

    func testProviderFailurePropagates() async {
        let architect = AIArchitect(provider: ThrowingAIProvider())
        do {
            _ = try await architect.generateDiagram(prompt: "anything")
            XCTFail("expected the provider's error to propagate")
        } catch AIProviderError.requestFailed(let message) {
            XCTAssertEqual(message, "offline")
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }

    func testExplainReturnsProviderCompletion() async throws {
        let architect = AIArchitect(provider: StubAIProvider(response: "This diagram shows a payment flow."))
        let explanation = try await architect.explain(summary: "3 nodes, 2 edges")
        XCTAssertEqual(explanation, "This diagram shows a payment flow.")
    }
}
