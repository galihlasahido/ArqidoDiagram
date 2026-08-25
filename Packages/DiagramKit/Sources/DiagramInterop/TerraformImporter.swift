import Foundation
import DiagramModel

/// Spec §22/§27 "Terraform -> Cloud Architecture". Terraform is HCL, not
/// YAML, so this doesn't reuse `MiniYAML` — instead it finds every
/// `resource "type" "name" { ... }` block (balanced-brace matched, the
/// same technique `SQLSchemaImporter` uses for parens) and infers real
/// dependency edges from Terraform's own implicit-reference convention
/// (`aws_subnet.main.id` inside another resource's body means that
/// resource depends on `aws_subnet.main`) plus explicit `depends_on`
/// lists — not just a flat list of unconnected resources.
public enum TerraformImporter {
    public static func parse(_ hcl: String) -> GeneratedDiagramSpec {
        let stripped = stripComments(hcl)
        let resources = extractResources(from: stripped)
        guard !resources.isEmpty else { return GeneratedDiagramSpec(nodes: [], edges: []) }

        let addresses = Set(resources.map { "\($0.type).\($0.name)" })
        var nodes: [GeneratedNodeSpec] = []
        var edges: [GeneratedEdgeSpec] = []

        for resource in resources {
            let id = "\(resource.type).\(resource.name)"
            nodes.append(GeneratedNodeSpec(id: id, label: resource.name, type: semanticType(forResourceType: resource.type)))

            for otherAddress in addresses where otherAddress != id {
                guard referencesAddress(otherAddress, in: resource.body) else { continue }
                edges.append(GeneratedEdgeSpec(from: id, to: otherAddress, label: "depends on"))
            }
        }

        return GeneratedDiagramSpec(nodes: nodes, edges: edges)
    }

    // MARK: - Parsing

    private struct Resource {
        let type: String
        let name: String
        let body: String
    }

    private static func extractResources(from text: String) -> [Resource] {
        var resources: [Resource] = []
        let pattern = #"resource\s+"([\w-]+)"\s+"([\w-]+)"\s*\{"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(text.startIndex..., in: text)

        for match in regex.matches(in: text, range: nsRange) {
            guard let typeRange = Range(match.range(at: 1), in: text),
                  let nameRange = Range(match.range(at: 2), in: text),
                  let wholeRange = Range(match.range, in: text) else { continue }
            let openBraceIndex = text.index(before: wholeRange.upperBound)
            guard let body = balancedBraceBody(in: text, openingAt: openBraceIndex) else { continue }
            resources.append(Resource(type: String(text[typeRange]), name: String(text[nameRange]), body: body))
        }
        return resources
    }

    private static func balancedBraceBody(in text: String, openingAt openBraceIndex: String.Index) -> String? {
        var depth = 0
        var index = openBraceIndex
        let bodyStart = text.index(after: openBraceIndex)
        while index < text.endIndex {
            if text[index] == "{" { depth += 1 }
            if text[index] == "}" {
                depth -= 1
                if depth == 0 { return String(text[bodyStart..<index]) }
            }
            index = text.index(after: index)
        }
        return nil
    }

    /// A resource address appears as a real reference only when it isn't
    /// part of a longer identifier — matched at a token boundary rather
    /// than a raw substring search. The address is normally followed by
    /// `.attribute` (`aws_subnet.main.id`), so a trailing `.` is a valid,
    /// *expected* boundary, not a disqualifying one — only a letter/digit/
    /// underscore/hyphen right after would mean this is actually a prefix
    /// of some other, longer identifier (e.g. `aws_vpc.main2`).
    private static func referencesAddress(_ address: String, in body: String) -> Bool {
        guard let range = body.range(of: address) else { return false }
        let before = range.lowerBound == body.startIndex ? " " : body[body.index(before: range.lowerBound)]
        let after = range.upperBound == body.endIndex ? " " : body[range.upperBound]
        let isIdentifierContinuation: (Character) -> Bool = { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        let beforeIsBoundary = !isIdentifierContinuation(before) && before != "."
        let afterIsBoundary = !isIdentifierContinuation(after)
        return beforeIsBoundary && afterIsBoundary
    }

    private static func stripComments(_ hcl: String) -> String {
        var lines = hcl.components(separatedBy: "\n")
        for i in lines.indices {
            if let range = lines[i].range(of: "#") {
                lines[i] = String(lines[i][lines[i].startIndex..<range.lowerBound])
            } else if let range = lines[i].range(of: "//") {
                lines[i] = String(lines[i][lines[i].startIndex..<range.lowerBound])
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Resource type -> semantic type

    private static func semanticType(forResourceType type: String) -> String {
        let lowered = type.lowercased()
        if lowered.contains("security_group") || lowered.contains("firewall") || lowered.contains("nsg") { return "firewall" }
        if lowered.contains("lb") || lowered.contains("load_balancer") || lowered.contains("elb") || lowered.contains("alb") { return "load balancer" }
        if lowered.contains("db") || lowered.contains("rds") || lowered.contains("sql") || lowered.contains("cosmosdb") || lowered.contains("dynamodb") { return "database" }
        if lowered.contains("bucket") || lowered.contains("storage") || lowered.contains("blob") { return "storage" }
        if lowered.contains("gateway") || lowered.contains("apigateway") { return "gateway" }
        if lowered.contains("vpc") || lowered.contains("vnet") || lowered.contains("network") || lowered.contains("subnet") { return "network" }
        if lowered.contains("cluster") && (lowered.contains("k8s") || lowered.contains("kubernetes") || lowered.contains("eks") || lowered.contains("aks") || lowered.contains("gke")) { return "kubernetes cluster" }
        if lowered.contains("function") || lowered.contains("lambda") { return "service" }
        if lowered.contains("instance") || lowered.contains("vm") || lowered.contains("compute") { return "service" }
        return "container"
    }
}
