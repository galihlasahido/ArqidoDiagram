import XCTest
import DiagramModel
@testable import DiagramPersistence

final class PackageRoundTripTests: XCTestCase {
    func testBlankDocumentRoundTripsThroughPackageWrapper() throws {
        let original = DiagramDocumentModel.blank(title: "Payment Architecture", at: Date(timeIntervalSince1970: 0))

        let wrapper = try PackageWriter.fileWrapper(for: original)
        let decoded = try PackageReader.documentModel(from: wrapper)

        XCTAssertEqual(decoded.documentID, original.documentID)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.pageOrder, original.pageOrder)
        XCTAssertEqual(decoded.pages[original.pageOrder[0]]?.name, "Page 1")
    }

    func testMultiPageDocumentWithNodesAndEdgesRoundTrips() throws {
        let node = DiagramNode(type: .rectangle, position: Point2D(x: 10, y: 20), size: Size2D(width: 100, height: 60))
        var page1 = DiagramPage(name: "System Context", order: 0)
        page1.nodes = [node.id: node]
        page1.nodeZOrder = [node.id]
        let page2 = DiagramPage(name: "Data Architecture", order: 1)

        var document = DiagramDocumentModel.blank(title: "Multi-page Doc", at: Date(timeIntervalSince1970: 0))
        document.pages = [page1.id: page1, page2.id: page2]
        document.pageOrder = [page1.id, page2.id]

        let wrapper = try PackageWriter.fileWrapper(for: document)
        let decoded = try PackageReader.documentModel(from: wrapper)

        XCTAssertEqual(decoded.pageOrder, [page1.id, page2.id])
        XCTAssertEqual(decoded.pages[page1.id]?.nodes[node.id]?.type, .rectangle)
        XCTAssertEqual(decoded.pages[page2.id]?.name, "Data Architecture")
    }

    func testMissingManifestThrowsRatherThanSilentlyLosingData() {
        let emptyWrapper = FileWrapper(directoryWithFileWrappers: [:])
        XCTAssertThrowsError(try PackageReader.documentModel(from: emptyWrapper)) { error in
            XCTAssertEqual(error as? PackageReadError, .missingManifest)
        }
    }

    /// A real (not simulated) mid-build failure: `JSONEncoder` legitimately
    /// refuses to encode non-finite `Double`s, so a node with an infinite
    /// coordinate throws partway through `PackageWriter.fileWrapper(for:)`.
    /// Confirms the DoD #19 guarantee end-to-end on real disk: the
    /// previously-saved package is byte-for-byte untouched by the failed
    /// attempt, because construction never got far enough to return
    /// anything for `NSDocument`'s atomic write path to act on.
    func testFailedEncodingLeavesPreviouslySavedPackageOnDiskUntouched() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let packageURL = tempDir.appendingPathComponent("Test.diagram")

        let goodDocument = DiagramDocumentModel.blank(title: "Good", at: Date(timeIntervalSince1970: 0))
        let goodWrapper = try PackageWriter.fileWrapper(for: goodDocument)
        try goodWrapper.write(to: packageURL, options: [.atomic], originalContentsURL: nil)

        var badNode = DiagramNode(type: .rectangle, position: Point2D(x: 10, y: 20), size: Size2D(width: 100, height: 60))
        badNode.position.x = .infinity
        var badPage = DiagramPage(name: "Bad", order: 0)
        badPage.nodes[badNode.id] = badNode
        var badDocument = DiagramDocumentModel.blank(title: "Bad", at: Date(timeIntervalSince1970: 0))
        badDocument.pages = [badPage.id: badPage]
        badDocument.pageOrder = [badPage.id]

        XCTAssertThrowsError(try PackageWriter.fileWrapper(for: badDocument))

        let rereadWrapper = try FileWrapper(url: packageURL)
        let reread = try PackageReader.documentModel(from: rereadWrapper)
        XCTAssertEqual(reread.title, "Good", "the previously-saved package must survive a failed subsequent save attempt untouched")
    }

    /// Round-trips through *actual disk I/O*, not just in-memory
    /// `FileWrapper`s — writes the package to a real temp directory,
    /// re-reads it via a fresh `FileWrapper(url:)`, and confirms every
    /// field survives. This is the same `FileWrapper.write(to:)` /
    /// `FileWrapper(url:)` pair `NSDocument` itself uses under the hood.
    func testFullDocumentRoundTripsThroughRealDiskIO() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let packageURL = tempDir.appendingPathComponent("RoundTrip.diagram")

        let node = DiagramNode(
            type: .flowchartDecision,
            position: Point2D(x: 42, y: 99),
            size: Size2D(width: 180, height: 90),
            rotation: 0.4,
            style: ShapeStyle(fill: ColorRef(red: 1, green: 0.4, blue: 0.7, alpha: 1), strokeWidth: 3),
            text: TextContent(string: "Ship it?"),
            metadata: Metadata(fields: ["owner": "Release Team"], tags: ["critical"])
        )
        let otherNode = DiagramNode(type: .flowchartDatabase, position: Point2D(x: 400, y: 99), size: Size2D(width: 140, height: 100))
        let edge = DiagramEdge(source: .node(node.id, portID: nil), target: .node(otherNode.id, portID: nil), routing: .orthogonal)

        var page1 = DiagramPage(name: "Release Flow", order: 0)
        page1.nodes = [node.id: node, otherNode.id: otherNode]
        page1.edges = [edge.id: edge]
        page1.nodeZOrder = [node.id, otherNode.id]
        page1.edgeZOrder = [edge.id]
        let page2 = DiagramPage(name: "Empty Page", order: 1)

        var original = DiagramDocumentModel.blank(title: "Release Process", at: Date(timeIntervalSince1970: 1_700_000_000))
        original.pages = [page1.id: page1, page2.id: page2]
        original.pageOrder = [page1.id, page2.id]

        let wrapper = try PackageWriter.fileWrapper(for: original)
        try wrapper.write(to: packageURL, options: [.atomic], originalContentsURL: nil)

        let rereadWrapper = try FileWrapper(url: packageURL)
        let reread = try PackageReader.documentModel(from: rereadWrapper)

        XCTAssertEqual(reread.title, original.title)
        XCTAssertEqual(reread.pageOrder, original.pageOrder)
        let rereadPage1 = try XCTUnwrap(reread.pages[page1.id])
        XCTAssertEqual(rereadPage1.nodes[node.id], node)
        XCTAssertEqual(rereadPage1.edges[edge.id]?.routing, .orthogonal)
        XCTAssertEqual(reread.pages[page2.id]?.name, "Empty Page")

        // The package is a real, Finder-visible directory structure, not an
        // opaque blob — spot-check the layout PackageWriter/Reader agree on.
        XCTAssertTrue(FileManager.default.fileExists(atPath: packageURL.appendingPathComponent("manifest.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: packageURL.appendingPathComponent("document.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: packageURL.appendingPathComponent("pages").path))
    }

    func testEncryptedPackageRoundTripsWithTheCorrectPassword() throws {
        let node = DiagramNode(type: .rectangle, position: Point2D(x: 10, y: 20), size: Size2D(width: 100, height: 60))
        var page = DiagramPage(name: "Confidential", order: 0)
        page.nodes = [node.id: node]
        page.nodeZOrder = [node.id]
        var document = DiagramDocumentModel.blank(title: "Secret Architecture", at: Date(timeIntervalSince1970: 0))
        document.pages = [page.id: page]
        document.pageOrder = [page.id]

        let wrapper = try PackageWriter.fileWrapper(for: document, password: "sw0rdfish")
        let decoded = try PackageReader.documentModel(from: wrapper, password: "sw0rdfish")

        XCTAssertEqual(decoded.title, "Secret Architecture")
        XCTAssertEqual(decoded.pages[page.id]?.nodes[node.id]?.type, .rectangle)
    }

    func testEncryptedPackageManifestStaysPlaintext() throws {
        let document = DiagramDocumentModel.blank(title: "Secret Architecture", at: Date(timeIntervalSince1970: 0))
        let wrapper = try PackageWriter.fileWrapper(for: document, password: "sw0rdfish")

        let manifestData = try XCTUnwrap(wrapper.fileWrappers?["manifest.json"]?.regularFileContents)
        let manifestString = String(data: manifestData, encoding: .utf8)
        XCTAssertTrue(manifestString?.contains(document.documentID.uuidString) ?? false)

        let documentJSONData = try XCTUnwrap(wrapper.fileWrappers?["document.json"]?.regularFileContents)
        // Ciphertext is arbitrary bytes — it may not even decode as UTF-8
        // at all, which is itself evidence it isn't plaintext JSON.
        XCTAssertFalse(String(data: documentJSONData, encoding: .utf8)?.contains("Secret Architecture") ?? false)
    }

    func testEncryptedPackageWithoutPasswordThrows() throws {
        let document = DiagramDocumentModel.blank(title: "Secret Architecture", at: Date(timeIntervalSince1970: 0))
        let wrapper = try PackageWriter.fileWrapper(for: document, password: "sw0rdfish")

        XCTAssertThrowsError(try PackageReader.documentModel(from: wrapper)) { error in
            XCTAssertEqual(error as? PackageReadError, .encryptionPasswordRequired)
        }
    }

    func testEncryptedPackageWithWrongPasswordThrows() throws {
        let document = DiagramDocumentModel.blank(title: "Secret Architecture", at: Date(timeIntervalSince1970: 0))
        let wrapper = try PackageWriter.fileWrapper(for: document, password: "sw0rdfish")

        XCTAssertThrowsError(try PackageReader.documentModel(from: wrapper, password: "wrong")) { error in
            XCTAssertEqual(error as? PackageReadError, .incorrectPassword)
        }
    }

    func testVersionsRoundTripThroughThePackage() throws {
        let document = DiagramDocumentModel.blank(title: "Current", at: Date(timeIntervalSince1970: 0))
        let earlierSnapshot = DiagramDocumentModel.blank(title: "Earlier Draft", at: Date(timeIntervalSince1970: 0))
        let version = DocumentVersion(createdAt: Date(timeIntervalSince1970: 100), note: "First working draft", snapshot: earlierSnapshot)

        let wrapper = try PackageWriter.fileWrapper(for: document, versions: [version])
        let decodedVersions = try PackageReader.versions(from: wrapper)

        XCTAssertEqual(decodedVersions.count, 1)
        XCTAssertEqual(decodedVersions.first?.note, "First working draft")
        XCTAssertEqual(decodedVersions.first?.snapshot.title, "Earlier Draft")
    }

    func testNoVersionsDirectoryYieldsAnEmptyArrayRatherThanThrowing() throws {
        let document = DiagramDocumentModel.blank(title: "Current", at: Date(timeIntervalSince1970: 0))
        let wrapper = try PackageWriter.fileWrapper(for: document)
        XCTAssertTrue(try PackageReader.versions(from: wrapper).isEmpty)
    }

    func testVersionsAreEncryptedWhenTheDocumentIs() throws {
        let document = DiagramDocumentModel.blank(title: "Current", at: Date(timeIntervalSince1970: 0))
        let version = DocumentVersion(note: "Snapshot", snapshot: document)
        let wrapper = try PackageWriter.fileWrapper(for: document, password: "sw0rdfish", versions: [version])

        XCTAssertThrowsError(try PackageReader.versions(from: wrapper)) { error in
            XCTAssertEqual(error as? PackageReadError, .encryptionPasswordRequired)
        }
        let decoded = try PackageReader.versions(from: wrapper, password: "sw0rdfish")
        XCTAssertEqual(decoded.first?.note, "Snapshot")
    }

    func testCurrentSchemaVersionRoundTripsWithoutMigration() throws {
        let document = DiagramDocumentModel.blank(at: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(document.schemaVersion, DiagramDocumentModel.currentSchemaVersion)

        let wrapper = try PackageWriter.fileWrapper(for: document)
        let decoded = try PackageReader.documentModel(from: wrapper)
        XCTAssertEqual(decoded.schemaVersion, DiagramDocumentModel.currentSchemaVersion)
    }
}
