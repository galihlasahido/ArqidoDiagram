import XCTest
@testable import DiagramPersistence

final class KeychainPasswordStoreTests: XCTestCase {
    func testSaveThenLoadReturnsTheSamePassword() {
        let documentID = UUID()
        defer { KeychainPasswordStore.delete(for: documentID) }

        KeychainPasswordStore.save(password: "hunter2", for: documentID)
        XCTAssertEqual(KeychainPasswordStore.load(for: documentID), "hunter2")
    }

    func testLoadForUnknownDocumentReturnsNil() {
        XCTAssertNil(KeychainPasswordStore.load(for: UUID()))
    }

    func testDeleteRemovesTheSavedPassword() {
        let documentID = UUID()
        KeychainPasswordStore.save(password: "hunter2", for: documentID)
        KeychainPasswordStore.delete(for: documentID)
        XCTAssertNil(KeychainPasswordStore.load(for: documentID))
    }
}
