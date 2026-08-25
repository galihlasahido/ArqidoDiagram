import Foundation
import DiagramModel

/// Spec §22/§27 "Kubernetes YAML -> Kubernetes Architecture". Parses a
/// (possibly multi-document, `---`-separated) manifest file into one node
/// per resource plus real inferred relationships: a Service's `selector`
/// matched against a Deployment/Pod's labels, an Ingress rule's backend
/// service name, and a container's ConfigMap references — not just a flat
/// list of unconnected boxes.
public enum KubernetesImporter {
    private struct Resource {
        let kind: String
        let name: String
        let labels: [String: String]
        let value: YAMLValue
    }

    public static func parse(_ manifest: String) -> GeneratedDiagramSpec {
        let documents = manifest.components(separatedBy: "\n---")
        let resources: [Resource] = documents.compactMap { document in
            let parsed = MiniYAML.parse(document)
            guard let kind = parsed["kind"]?.stringValue, let name = parsed["metadata"]?["name"]?.stringValue else { return nil }
            let labels = extractLabels(parsed["metadata"]?["labels"])
            return Resource(kind: kind, name: name, labels: labels, value: parsed)
        }
        guard !resources.isEmpty else { return GeneratedDiagramSpec(nodes: [], edges: []) }

        var nodes: [GeneratedNodeSpec] = []
        var edges: [GeneratedEdgeSpec] = []
        func nodeID(_ resource: Resource) -> String { "\(resource.kind)_\(resource.name)" }

        for resource in resources {
            nodes.append(GeneratedNodeSpec(id: nodeID(resource), label: resource.name, type: "kubernetes \(resource.kind.lowercased())"))
        }

        let deploymentsAndPods = resources.filter { $0.kind == "Deployment" || $0.kind == "Pod" || $0.kind == "StatefulSet" }
        for service in resources.filter({ $0.kind == "Service" }) {
            let selector = extractLabels(service.value["spec"]?["selector"])
            guard !selector.isEmpty else { continue }
            for target in deploymentsAndPods {
                let targetLabels = target.kind == "Pod" ? target.labels : extractLabels(target.value["spec"]?["template"]?["metadata"]?["labels"])
                if selector.allSatisfy({ targetLabels[$0.key] == $0.value }) {
                    edges.append(GeneratedEdgeSpec(from: nodeID(service), to: nodeID(target)))
                }
            }
        }

        for ingress in resources.filter({ $0.kind == "Ingress" }) {
            for backendServiceName in ingressBackendServiceNames(ingress.value) {
                if let service = resources.first(where: { $0.kind == "Service" && $0.name == backendServiceName }) {
                    edges.append(GeneratedEdgeSpec(from: nodeID(ingress), to: nodeID(service)))
                }
            }
        }

        for target in deploymentsAndPods {
            let podSpec = target.kind == "Pod" ? target.value["spec"] : target.value["spec"]?["template"]?["spec"]
            for configMapName in configMapReferences(podSpec) {
                if let configMap = resources.first(where: { $0.kind == "ConfigMap" && $0.name == configMapName }) {
                    edges.append(GeneratedEdgeSpec(from: nodeID(configMap), to: nodeID(target), label: "configures"))
                }
            }
        }

        return GeneratedDiagramSpec(nodes: nodes, edges: edges)
    }

    private static func extractLabels(_ value: YAMLValue?) -> [String: String] {
        guard case .mapping(let pairs) = value else { return [:] }
        var result: [String: String] = [:]
        for pair in pairs {
            if let string = pair.value.stringValue { result[pair.key] = string }
        }
        return result
    }

    private static func ingressBackendServiceNames(_ ingress: YAMLValue) -> [String] {
        guard let rules = ingress["spec"]?["rules"]?.arrayValue else { return [] }
        var names: [String] = []
        for rule in rules {
            guard let paths = rule["http"]?["paths"]?.arrayValue else { continue }
            for path in paths {
                if let name = path["backend"]?["service"]?["name"]?.stringValue {
                    names.append(name)
                } else if let name = path["backend"]?["serviceName"]?.stringValue {
                    names.append(name)
                }
            }
        }
        return names
    }

    private static func configMapReferences(_ podSpec: YAMLValue?) -> [String] {
        guard let containers = podSpec?["containers"]?.arrayValue else { return [] }
        var names: [String] = []
        for container in containers {
            if let envFrom = container["envFrom"]?.arrayValue {
                for entry in envFrom {
                    if let name = entry["configMapRef"]?["name"]?.stringValue { names.append(name) }
                }
            }
        }
        if let volumes = podSpec?["volumes"]?.arrayValue {
            for volume in volumes {
                if let name = volume["configMap"]?["name"]?.stringValue { names.append(name) }
            }
        }
        return names
    }
}
