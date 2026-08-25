import XCTest
import DiagramModel
@testable import DiagramPersistence

final class CustomComponentLibraryTests: XCTestCase {
    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeComponent(name: String) -> CustomComponent {
        let node = DiagramNode(type: .rectangle, position: Point2D(x: 0, y: 0), size: Size2D(width: 100, height: 60))
        return CustomComponent(name: name, category: "Networking", nodes: [node], edges: [])
    }

    func testSavedComponentPersistsAcrossLibraryInstances() throws {
        let dir = try makeTempDirectory()
        let library = CustomComponentLibrary(directory: dir)
        library.save(makeComponent(name: "Load Balancer Pair"))

        let reloaded = CustomComponentLibrary(directory: dir)
        XCTAssertEqual(reloaded.components.count, 1)
        XCTAssertEqual(reloaded.components.first?.name, "Load Balancer Pair")
        XCTAssertEqual(reloaded.components.first?.category, "Networking")
    }

    func testDeleteRemovesComponentFromDiskToo() throws {
        let dir = try makeTempDirectory()
        let library = CustomComponentLibrary(directory: dir)
        let component = makeComponent(name: "Three Tier")
        library.save(component)
        library.delete(id: component.id)

        let reloaded = CustomComponentLibrary(directory: dir)
        XCTAssertTrue(reloaded.components.isEmpty)
    }

    func testMissingFileStartsWithAnEmptyLibraryRatherThanThrowing() throws {
        let dir = try makeTempDirectory()
        let library = CustomComponentLibrary(directory: dir)
        XCTAssertTrue(library.components.isEmpty)
    }
}
