import XCTest
@testable import DiagramInterop

final class MiniYAMLTests: XCTestCase {
    func testSimpleMapping() {
        let yaml = """
        name: Payment Platform
        version: 1
        """
        let parsed = MiniYAML.parse(yaml)
        XCTAssertEqual(parsed["name"]?.stringValue, "Payment Platform")
        XCTAssertEqual(parsed["version"]?.stringValue, "1")
    }

    func testNestedMapping() {
        let yaml = """
        metadata:
          name: my-service
          labels:
            app: web
        """
        let parsed = MiniYAML.parse(yaml)
        XCTAssertEqual(parsed["metadata"]?["name"]?.stringValue, "my-service")
        XCTAssertEqual(parsed["metadata"]?["labels"]?["app"]?.stringValue, "web")
    }

    func testSequenceOfScalars() {
        let yaml = """
        tags:
          - production
          - payments
        """
        let parsed = MiniYAML.parse(yaml)
        let tags = parsed["tags"]?.arrayValue?.compactMap(\.stringValue)
        XCTAssertEqual(tags, ["production", "payments"])
    }

    func testSequenceOfMappings() {
        let yaml = """
        services:
          - name: API Gateway
            type: gateway
          - name: Payment Service
            type: service
        """
        let parsed = MiniYAML.parse(yaml)
        let services = parsed["services"]?.arrayValue
        XCTAssertEqual(services?.count, 2)
        XCTAssertEqual(services?[0]["name"]?.stringValue, "API Gateway")
        XCTAssertEqual(services?[0]["type"]?.stringValue, "gateway")
        XCTAssertEqual(services?[1]["name"]?.stringValue, "Payment Service")
    }

    func testIgnoresCommentsAndBlankLines() {
        let yaml = """
        # top comment
        name: test

        # another comment
        value: 42  # trailing comment
        """
        let parsed = MiniYAML.parse(yaml)
        XCTAssertEqual(parsed["name"]?.stringValue, "test")
        XCTAssertEqual(parsed["value"]?.stringValue, "42")
    }

    func testQuotedStringsWithSpecialCharacters() {
        let yaml = """
        message: "hello: world # not a comment"
        single: 'it''s fine'
        """
        let parsed = MiniYAML.parse(yaml)
        XCTAssertEqual(parsed["message"]?.stringValue, "hello: world # not a comment")
    }

    func testRealisticKubernetesDeployment() {
        let yaml = """
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: web-app
        spec:
          replicas: 3
          selector:
            matchLabels:
              app: web-app
          template:
            spec:
              containers:
                - name: web
                  image: nginx:latest
                  ports:
                    - containerPort: 80
        """
        let parsed = MiniYAML.parse(yaml)
        XCTAssertEqual(parsed["kind"]?.stringValue, "Deployment")
        XCTAssertEqual(parsed["metadata"]?["name"]?.stringValue, "web-app")
        XCTAssertEqual(parsed["spec"]?["replicas"]?.stringValue, "3")
        let containers = parsed["spec"]?["template"]?["spec"]?["containers"]?.arrayValue
        XCTAssertEqual(containers?.first?["name"]?.stringValue, "web")
        XCTAssertEqual(containers?.first?["image"]?.stringValue, "nginx:latest")
    }

    func testRealisticDockerCompose() {
        let yaml = """
        version: "3.8"
        services:
          web:
            image: nginx
            depends_on:
              - api
          api:
            build: .
            ports:
              - "8080:8080"
        """
        let parsed = MiniYAML.parse(yaml)
        XCTAssertEqual(parsed["services"]?["web"]?["image"]?.stringValue, "nginx")
        XCTAssertEqual(parsed["services"]?["api"]?["build"]?.stringValue, ".")
        let dependsOn = parsed["services"]?["web"]?["depends_on"]?.arrayValue?.compactMap(\.stringValue)
        XCTAssertEqual(dependsOn, ["api"])
    }
}
