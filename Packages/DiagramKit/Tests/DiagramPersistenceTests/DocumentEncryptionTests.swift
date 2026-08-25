import XCTest
@testable import DiagramPersistence

final class DocumentEncryptionTests: XCTestCase {
    /// A low iteration count keeps these tests fast — `makeEnvelope()`'s
    /// real 200k-iteration default is exercised separately by
    /// `testDefaultEnvelopeUsesAHighIterationCount`, without paying its
    /// cost (by design: several seconds) in every other test here.
    private func fastEnvelope() -> DocumentEncryption.Envelope {
        DocumentEncryption.Envelope(salt: DocumentEncryption.makeEnvelope().salt, iterations: 1000)
    }

    func testEncryptDecryptRoundTrips() throws {
        let plaintext = "{\"secret\":\"payment gateway topology\"}".data(using: .utf8)!
        let envelope = fastEnvelope()

        let ciphertext = try DocumentEncryption.encrypt(plaintext, password: "correct horse battery staple", envelope: envelope)
        XCTAssertNotEqual(ciphertext, plaintext)

        let decrypted = try DocumentEncryption.decrypt(ciphertext, password: "correct horse battery staple", envelope: envelope)
        XCTAssertEqual(decrypted, plaintext)
    }

    func testWrongPasswordFailsToDecrypt() throws {
        let plaintext = "top secret".data(using: .utf8)!
        let envelope = fastEnvelope()
        let ciphertext = try DocumentEncryption.encrypt(plaintext, password: "right password", envelope: envelope)

        XCTAssertThrowsError(try DocumentEncryption.decrypt(ciphertext, password: "wrong password", envelope: envelope)) { error in
            XCTAssertEqual(error as? EncryptionError, .incorrectPasswordOrCorruptData)
        }
    }

    func testEmptyPasswordThrows() {
        let envelope = fastEnvelope()
        XCTAssertThrowsError(try DocumentEncryption.encrypt(Data(), password: "", envelope: envelope)) { error in
            XCTAssertEqual(error as? EncryptionError, .emptyPassword)
        }
    }

    func testDifferentSaltsProduceDifferentCiphertextForSamePassword() throws {
        let plaintext = "same content".data(using: .utf8)!
        let envelopeA = fastEnvelope()
        let envelopeB = fastEnvelope()

        let ciphertextA = try DocumentEncryption.encrypt(plaintext, password: "shared password", envelope: envelopeA)
        let ciphertextB = try DocumentEncryption.encrypt(plaintext, password: "shared password", envelope: envelopeB)
        XCTAssertNotEqual(ciphertextA, ciphertextB)
    }

    func testDefaultEnvelopeUsesAHighIterationCount() {
        XCTAssertGreaterThanOrEqual(DocumentEncryption.makeEnvelope().iterations, 100_000)
    }
}
