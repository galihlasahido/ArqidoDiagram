import DiagramModel

/// The architectural role a node plays, for rules that need to reason about
/// "is this a database", "is this externally exposed", etc. without a
/// dedicated typed field on `DiagramNode`. Resolved from two honest,
/// low-cost signals — `Metadata.semanticType` (an explicit, user-set value)
/// takes priority; a node's `ShapeType` is the fallback, so the built-in
/// rules produce sensible results even on a diagram nobody has tagged yet.
/// This is a heuristic classifier, not a type system — it can misclassify
/// unconventional diagrams, which is why every finding it feeds into names
/// the specific node(s) involved rather than asserting silent certainty.
enum NodeRole: Hashable {
    case external, firewall, waf, gateway, loadBalancer, service, database, cache, queue, identity, unknown

    static func of(_ node: DiagramNode) -> NodeRole {
        if let semantic = node.metadata.semanticType?.lowercased(), !semantic.isEmpty {
            if semantic.contains("firewall") { return .firewall }
            if semantic.contains("waf") { return .waf }
            if semantic.contains("gateway") { return .gateway }
            if semantic.contains("load") { return .loadBalancer }
            if semantic.contains("database") || semantic.contains("db") { return .database }
            if semantic.contains("cache") { return .cache }
            if semantic.contains("queue") { return .queue }
            if semantic.contains("identity") || semantic.contains("iam") { return .identity }
            if semantic.contains("external") || semantic.contains("internet") || semantic.contains("public") { return .external }
            if semantic.contains("service") { return .service }
        }

        switch node.type {
        case .networkFirewall:
            return .firewall
        case .securityWAF:
            return .waf
        case .networkGateway, .networkProxy:
            return .gateway
        case .networkLoadBalancer:
            return .loadBalancer
        case .erdEntity, .networkNAS, .flowchartDatabase:
            return .database
        case .networkInternet, .c4ExternalSystem, .networkWiFi:
            return .external
        case .securityIAM:
            return .identity
        case .c4Container, .c4Component, .c4SoftwareSystem, .umlComponent, .bpmnTask, .networkServer:
            return .service
        default:
            return .unknown
        }
    }
}
