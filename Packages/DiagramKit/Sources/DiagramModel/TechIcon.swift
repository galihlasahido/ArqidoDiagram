import Foundation

/// Which vendor pack a `TechIconType` belongs to. Kept as its own dimension
/// (rather than folded into name/tags) because the spec calls for
/// vendor-specific icon packs to stay modular so their licenses can be
/// handled independently — even though every icon in this catalog today is
/// original artwork (see `TechIconCatalogEntry.license`), a future pack of
/// real, separately-licensed vendor icons only has to plug in alongside
/// these, not replace this type.
public enum IconPack: String, Codable, Sendable, CaseIterable {
    case aws = "AWS"
    case azure = "Azure"
    case gcp = "Google Cloud"
    case kubernetes = "Kubernetes"
}

/// A closed catalog, same rationale as `ShapeType`: these represent generic
/// architectural concepts (compute, storage, a pod, a queue) rather than a
/// plugin system, so a flat enum is simpler and safer than a dynamic
/// registry. Every case is an original, generic pictogram — not a
/// reproduction of any vendor's trademarked logo (see `native-macos-
/// enterprise-diagramming-plan-and-prompt.md` §"ICON SYSTEM": "Never scrape
/// random icons").
public enum TechIconType: String, Codable, Sendable, CaseIterable {
    case awsCompute, awsStorage, awsDatabase, awsContainer, awsFunction
    case azureCompute, azureStorage, azureDatabase, azureContainer, azureFunction
    case gcpCompute, gcpStorage, gcpDatabase, gcpContainer, gcpFunction
    case kubernetesPod, kubernetesService, kubernetesDeployment, kubernetesCluster, kubernetesIngress, kubernetesConfigMap
}

public struct TechIconCatalogEntry: Identifiable, Sendable {
    public let id: TechIconType
    public let name: String
    public let pack: IconPack
    public let tags: [String]
    public let source: String
    public let license: String
    public let version: String

    public init(id: TechIconType, name: String, pack: IconPack, tags: [String]) {
        self.id = id
        self.name = name
        self.pack = pack
        self.tags = tags
        self.source = "Original artwork drawn for ArqidoDiagram — a generic representation, not a vendor logo or trademark"
        self.license = "Original work; free to use within this project"
        self.version = "1.0"
    }
}

public enum TechIconCatalog {
    public static let all: [TechIconCatalogEntry] = aws + azure + gcp + kubernetes

    public static func entries(for pack: IconPack) -> [TechIconCatalogEntry] {
        all.filter { $0.pack == pack }
    }

    public static let aws: [TechIconCatalogEntry] = [
        TechIconCatalogEntry(id: .awsCompute, name: "Compute", pack: .aws, tags: ["ec2", "vm", "instance"]),
        TechIconCatalogEntry(id: .awsStorage, name: "Storage", pack: .aws, tags: ["s3", "bucket", "object storage"]),
        TechIconCatalogEntry(id: .awsDatabase, name: "Database", pack: .aws, tags: ["rds", "dynamodb"]),
        TechIconCatalogEntry(id: .awsContainer, name: "Container Service", pack: .aws, tags: ["ecs", "fargate"]),
        TechIconCatalogEntry(id: .awsFunction, name: "Function", pack: .aws, tags: ["lambda", "serverless"])
    ]

    public static let azure: [TechIconCatalogEntry] = [
        TechIconCatalogEntry(id: .azureCompute, name: "Compute", pack: .azure, tags: ["vm", "instance"]),
        TechIconCatalogEntry(id: .azureStorage, name: "Storage", pack: .azure, tags: ["blob", "storage account"]),
        TechIconCatalogEntry(id: .azureDatabase, name: "Database", pack: .azure, tags: ["sql", "cosmos db"]),
        TechIconCatalogEntry(id: .azureContainer, name: "Container Service", pack: .azure, tags: ["aks", "container instance"]),
        TechIconCatalogEntry(id: .azureFunction, name: "Function", pack: .azure, tags: ["functions", "serverless"])
    ]

    public static let gcp: [TechIconCatalogEntry] = [
        TechIconCatalogEntry(id: .gcpCompute, name: "Compute", pack: .gcp, tags: ["compute engine", "vm"]),
        TechIconCatalogEntry(id: .gcpStorage, name: "Storage", pack: .gcp, tags: ["cloud storage", "bucket"]),
        TechIconCatalogEntry(id: .gcpDatabase, name: "Database", pack: .gcp, tags: ["cloud sql", "firestore"]),
        TechIconCatalogEntry(id: .gcpContainer, name: "Container Service", pack: .gcp, tags: ["gke", "cloud run"]),
        TechIconCatalogEntry(id: .gcpFunction, name: "Function", pack: .gcp, tags: ["cloud functions", "serverless"])
    ]

    public static let kubernetes: [TechIconCatalogEntry] = [
        TechIconCatalogEntry(id: .kubernetesPod, name: "Pod", pack: .kubernetes, tags: ["pod"]),
        TechIconCatalogEntry(id: .kubernetesService, name: "Service", pack: .kubernetes, tags: ["svc"]),
        TechIconCatalogEntry(id: .kubernetesDeployment, name: "Deployment", pack: .kubernetes, tags: ["deployment", "replicaset"]),
        TechIconCatalogEntry(id: .kubernetesCluster, name: "Cluster", pack: .kubernetes, tags: ["cluster", "node pool"]),
        TechIconCatalogEntry(id: .kubernetesIngress, name: "Ingress", pack: .kubernetes, tags: ["ingress", "gateway"]),
        TechIconCatalogEntry(id: .kubernetesConfigMap, name: "ConfigMap", pack: .kubernetes, tags: ["configmap", "config"])
    ]
}
