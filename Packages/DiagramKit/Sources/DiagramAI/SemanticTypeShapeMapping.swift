import DiagramModel

/// Picks a concrete `ShapeType` for a generated node's free-text `type`
/// string ("gateway", "database", "kubernetes pod", ...) — the inverse of
/// `DiagramValidation.NodeRole`'s classifier, but kept here rather than
/// shared: that one only needs a handful of coarse roles for rule
/// matching, this one needs an actual shape to draw, so the keyword list
/// is deliberately more specific.
public enum SemanticTypeShapeMapping {
    public static func shapeType(for type: String) -> ShapeType {
        let lowered = type.lowercased()

        if lowered.contains("firewall") { return .networkFirewall }
        if lowered.contains("waf") { return .securityWAF }
        if lowered.contains("load balancer") || lowered.contains("loadbalancer") { return .networkLoadBalancer }
        if lowered.contains("gateway") { return .networkGateway }
        if lowered.contains("proxy") { return .networkProxy }
        if lowered.contains("database") || lowered == "db" { return .flowchartDatabase }
        if lowered.contains("cache") || lowered.contains("queue") || lowered.contains("broker") { return .networkServer }
        if lowered.contains("identity") || lowered.contains("iam") { return .securityIAM }
        if lowered.contains("mfa") { return .securityMFA }
        if lowered.contains("siem") { return .securitySIEM }
        if lowered.contains("soc") { return .securitySOC }
        if lowered.contains("kms") { return .securityKMS }
        if lowered.contains("hsm") { return .securityHSM }
        if lowered.contains("dlp") { return .securityDLP }
        if lowered.contains("zero trust") { return .securityZeroTrust }
        if lowered.contains("external") || lowered.contains("internet") || lowered.contains("third-party") || lowered.contains("third party") { return .networkInternet }
        if lowered.contains("actor") || lowered.contains("user") || lowered.contains("person") || lowered.contains("customer") { return .c4Person }
        if lowered.contains("kubernetes") || lowered.contains("k8s") || lowered.contains("pod") { return .roundedRectangle }
        if lowered.contains("container") { return .container }
        if lowered.contains("microservice") || lowered.contains("service") { return .c4Container }
        if lowered.contains("system") { return .c4SoftwareSystem }
        if lowered.contains("component") { return .c4Component }
        if lowered.contains("entity") { return .erdEntity }
        if lowered.contains("event") { return .bpmnIntermediateEvent }
        if lowered.contains("task") || lowered.contains("process") { return .bpmnTask }
        if lowered.contains("decision") || lowered.contains("gateway condition") { return .flowchartDecision }
        if lowered.contains("class") { return .umlClass }
        if lowered.contains("interface") { return .umlInterface }
        if lowered.contains("use case") || lowered.contains("usecase") { return .umlUseCase }
        if lowered.contains("network") || lowered.contains("router") { return .networkRouter }
        if lowered.contains("server") { return .networkServer }
        if lowered.contains("storage") || lowered.contains("nas") { return .networkNAS }

        return .roundedRectangle
    }
}
