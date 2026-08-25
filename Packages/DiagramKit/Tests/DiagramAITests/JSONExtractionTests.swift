import XCTest
@testable import DiagramAI

final class JSONExtractionTests: XCTestCase {
    func testExtractsPlainJSONObject() {
        let text = "{\"a\":1}"
        XCTAssertEqual(JSONExtraction.firstJSONObject(in: text), text)
    }

    func testIgnoresTrailingSSETerminator() {
        // The exact quirk seen from the configured proxy: a normal JSON
        // body followed by `data: [DONE]` even for a non-streaming request.
        let text = "{\"a\":1}data: [DONE]"
        XCTAssertEqual(JSONExtraction.firstJSONObject(in: text), "{\"a\":1}")
    }

    func testHandlesNestedBraces() {
        let text = "{\"a\":{\"b\":{\"c\":1}}}"
        XCTAssertEqual(JSONExtraction.firstJSONObject(in: text), text)
    }

    func testIgnoresBracesInsideStringLiterals() {
        let text = "{\"a\":\"literal { brace }\"}"
        XCTAssertEqual(JSONExtraction.firstJSONObject(in: text), text)
    }

    func testHandlesEscapedQuotesInsideStrings() {
        let text = "{\"a\":\"she said \\\"hi\\\"\"}"
        XCTAssertEqual(JSONExtraction.firstJSONObject(in: text), text)
    }

    func testExtractsFromMarkdownCodeFence() {
        let text = "Sure, here's the JSON:\n```json\n{\"a\":1}\n```\nHope that helps."
        XCTAssertEqual(JSONExtraction.firstJSONObject(in: text), "{\"a\":1}")
    }

    func testReturnsNilWhenNoObjectPresent() {
        XCTAssertNil(JSONExtraction.firstJSONObject(in: "no json here"))
    }

    func testReturnsNilWhenBracesNeverClose() {
        XCTAssertNil(JSONExtraction.firstJSONObject(in: "{\"a\":1"))
    }
}
