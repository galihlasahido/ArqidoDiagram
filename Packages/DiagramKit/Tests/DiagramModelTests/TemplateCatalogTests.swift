import XCTest
@testable import DiagramModel

final class TemplateCatalogTests: XCTestCase {
    func testEveryTemplateProducesAPageWithAtLeastTwoConnectedNodes() {
        for template in TemplateCatalog.all {
            let page = template.makePage()
            XCTAssertGreaterThanOrEqual(page.nodes.count, 2, "\(template.name) has too few nodes")
            XCTAssertFalse(page.edges.isEmpty, "\(template.name) has no edges")
        }
    }

    func testEveryTemplateEdgeReferencesAnExistingNode() {
        for template in TemplateCatalog.all {
            let page = template.makePage()
            for edge in page.edges.values {
                if case .node(let sourceID, _) = edge.source {
                    XCTAssertNotNil(page.nodes[sourceID], "\(template.name): edge source \(sourceID) missing from nodes")
                }
                if case .node(let targetID, _) = edge.target {
                    XCTAssertNotNil(page.nodes[targetID], "\(template.name): edge target \(targetID) missing from nodes")
                }
            }
        }
    }

    func testTemplateIDsAreUnique() {
        let ids = TemplateCatalog.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "duplicate template ids found")
    }

    func testEveryCategoryHasAtLeastOneTemplate() {
        for category in TemplateCategory.allCases {
            XCTAssertFalse(TemplateCatalog.entries(for: category).isEmpty, "\(category.rawValue) has no templates")
        }
    }
}
