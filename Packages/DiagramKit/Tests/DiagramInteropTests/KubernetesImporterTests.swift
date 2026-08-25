import XCTest
@testable import DiagramInterop

final class KubernetesImporterTests: XCTestCase {
    func testFullStackWithRealRelationships() {
        let manifest = """
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: web-app
        spec:
          template:
            metadata:
              labels:
                app: web-app
            spec:
              containers:
                - name: web
                  image: nginx:latest
                  envFrom:
                    - configMapRef:
                        name: web-config
        ---
        apiVersion: v1
        kind: Service
        metadata:
          name: web-service
        spec:
          selector:
            app: web-app
        ---
        apiVersion: networking.k8s.io/v1
        kind: Ingress
        metadata:
          name: web-ingress
        spec:
          rules:
            - http:
                paths:
                  - backend:
                      service:
                        name: web-service
        ---
        apiVersion: v1
        kind: ConfigMap
        metadata:
          name: web-config
        """
        let spec = KubernetesImporter.parse(manifest)

        XCTAssertEqual(spec.nodes.count, 4)
        XCTAssertTrue(spec.nodes.contains { $0.label == "web-app" && $0.type == "kubernetes deployment" })
        XCTAssertTrue(spec.nodes.contains { $0.label == "web-service" && $0.type == "kubernetes service" })
        XCTAssertTrue(spec.nodes.contains { $0.label == "web-ingress" && $0.type == "kubernetes ingress" })
        XCTAssertTrue(spec.nodes.contains { $0.label == "web-config" && $0.type == "kubernetes configmap" })

        // Service -> Deployment (label selector match)
        XCTAssertTrue(spec.edges.contains { $0.from == "Service_web-service" && $0.to == "Deployment_web-app" })
        // Ingress -> Service (backend name match)
        XCTAssertTrue(spec.edges.contains { $0.from == "Ingress_web-ingress" && $0.to == "Service_web-service" })
        // ConfigMap -> Deployment (envFrom reference)
        XCTAssertTrue(spec.edges.contains { $0.from == "ConfigMap_web-config" && $0.to == "Deployment_web-app" && $0.label == "configures" })
    }

    func testServiceWithNoMatchingSelectorProducesNoEdge() {
        let manifest = """
        kind: Deployment
        metadata:
          name: app-a
        spec:
          template:
            metadata:
              labels:
                app: app-a
        ---
        kind: Service
        metadata:
          name: svc-b
        spec:
          selector:
            app: app-b
        """
        let spec = KubernetesImporter.parse(manifest)
        XCTAssertTrue(spec.edges.isEmpty)
    }

    func testEmptyManifestProducesEmptySpec() {
        let spec = KubernetesImporter.parse("")
        XCTAssertTrue(spec.nodes.isEmpty)
        XCTAssertTrue(spec.edges.isEmpty)
    }
}
