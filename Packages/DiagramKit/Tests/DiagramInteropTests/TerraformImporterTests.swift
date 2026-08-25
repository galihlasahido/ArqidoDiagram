import XCTest
@testable import DiagramInterop

final class TerraformImporterTests: XCTestCase {
    func testInfersImplicitDependenciesFromAttributeReferences() {
        let hcl = """
        resource "aws_vpc" "main" {
          cidr_block = "10.0.0.0/16"
        }

        resource "aws_subnet" "web" {
          vpc_id = aws_vpc.main.id
        }

        resource "aws_instance" "app" {
          subnet_id = aws_subnet.web.id
        }
        """
        let spec = TerraformImporter.parse(hcl)

        XCTAssertEqual(spec.nodes.count, 3)
        XCTAssertTrue(spec.edges.contains { $0.from == "aws_subnet.web" && $0.to == "aws_vpc.main" })
        XCTAssertTrue(spec.edges.contains { $0.from == "aws_instance.app" && $0.to == "aws_subnet.web" })
    }

    func testMapsCommonResourceTypesToSemanticRoles() {
        let hcl = """
        resource "aws_security_group" "web" {}
        resource "aws_db_instance" "primary" {}
        resource "aws_lb" "public" {}
        resource "aws_s3_bucket" "assets" {}
        """
        let spec = TerraformImporter.parse(hcl)
        XCTAssertEqual(spec.nodes.first { $0.label == "web" }?.type, "firewall")
        XCTAssertEqual(spec.nodes.first { $0.label == "primary" }?.type, "database")
        XCTAssertEqual(spec.nodes.first { $0.label == "public" }?.type, "load balancer")
        XCTAssertEqual(spec.nodes.first { $0.label == "assets" }?.type, "storage")
    }

    func testIgnoresCommentsAndUnrelatedText() {
        let hcl = """
        # top-level comment
        resource "aws_instance" "web" {
          ami = "ami-123" // trailing comment
        }
        """
        let spec = TerraformImporter.parse(hcl)
        XCTAssertEqual(spec.nodes.count, 1)
        XCTAssertEqual(spec.nodes.first?.label, "web")
    }

    func testEmptyInputProducesEmptySpec() {
        let spec = TerraformImporter.parse("")
        XCTAssertTrue(spec.nodes.isEmpty)
        XCTAssertTrue(spec.edges.isEmpty)
    }
}
