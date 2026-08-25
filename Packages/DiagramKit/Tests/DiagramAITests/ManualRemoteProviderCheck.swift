import XCTest
@testable import DiagramAI

/// Not part of the automated suite (skips unless `ARQIDO_AI_MANUAL_CHECK=1`
/// is set) — a one-off, human-triggered sanity check that `RemoteAIProvider`
/// actually round-trips against a real endpoint, reading the key from the
/// Keychain rather than hardcoding it anywhere.
final class ManualRemoteProviderCheck: XCTestCase {
    func testLiveRoundTrip() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["ARQIDO_AI_MANUAL_CHECK"] == "1", "manual-only check")

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        task.arguments = ["find-generic-password", "-a", "openagentic", "-s", "com.arqido.ArqidoDiagram.aiProvider", "-w"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try task.run()
        task.waitUntilExit()
        let apiKey = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        XCTAssertFalse(apiKey.isEmpty, "no key found in Keychain — run the seed command first")

        let provider = RemoteAIProvider(baseURL: URL(string: "https://openagentic.id/api/v1")!, apiKey: apiKey, model: "gemini-3.5-flash")
        let architect = AIArchitect(provider: provider)
        let result = try await architect.generateDiagram(prompt: "A payment gateway architecture with an API Gateway, a Payment Service, and a PostgreSQL database.")

        XCTAssertGreaterThanOrEqual(result.nodes.count, 2)
        print("LIVE CHECK nodes: \(result.nodes.map { ($0.text?.string ?? "?", $0.type.rawValue) })")
        print("LIVE CHECK edges: \(result.edges.count)")
    }
}
