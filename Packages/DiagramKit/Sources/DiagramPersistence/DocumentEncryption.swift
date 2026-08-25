import Foundation
import CryptoKit
import Security

/// Optional document encryption (spec §SECURITY: "Optional encrypted
/// documents"). AES-GCM keyed by a password-derived key — PBKDF2-HMAC-
/// SHA256 with a random salt and a high iteration count, implemented by
/// hand (via `HMAC<SHA256>`) since CryptoKit ships AES-GCM but not a
/// password-based KDF, and pulling in CommonCrypto just for PBKDF2 would
/// mean fighting SPM's C-interop module map for one function.
public enum DocumentEncryption {
    public struct Envelope: Codable, Sendable {
        public let salt: Data
        public let iterations: Int

        public init(salt: Data, iterations: Int) {
            self.salt = salt
            self.iterations = iterations
        }
    }

    public static let defaultIterations = 200_000
    private static let keyLength = 32 // 256-bit AES key

    public static func makeEnvelope() -> Envelope {
        var salt = Data(count: 16)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        return Envelope(salt: salt, iterations: defaultIterations)
    }

    public static func encrypt(_ plaintext: Data, password: String, envelope: Envelope) throws -> Data {
        let key = try deriveKey(password: password, envelope: envelope)
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else { throw EncryptionError.sealingFailed }
        return combined
    }

    public static func decrypt(_ ciphertext: Data, password: String, envelope: Envelope) throws -> Data {
        let key = try deriveKey(password: password, envelope: envelope)
        let sealedBox = try AES.GCM.SealedBox(combined: ciphertext)
        do {
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            // CryptoKit's own error doesn't distinguish "wrong key" from
            // other failures — callers only need to know decryption
            // failed, most likely because the password was wrong.
            throw EncryptionError.incorrectPasswordOrCorruptData
        }
    }

    private static func deriveKey(password: String, envelope: Envelope) throws -> SymmetricKey {
        guard let passwordData = password.data(using: .utf8), !passwordData.isEmpty else {
            throw EncryptionError.emptyPassword
        }
        let derived = pbkdf2(
            password: passwordData,
            salt: envelope.salt,
            iterations: envelope.iterations,
            keyLength: keyLength
        )
        return SymmetricKey(data: derived)
    }

    /// PBKDF2-HMAC-SHA256 per RFC 8018: derive `keyLength` bytes by
    /// concatenating `HMAC(password, salt || blockIndex)` iterated blocks,
    /// XOR-folding each block's `iterations` rounds together.
    private static func pbkdf2(password: Data, salt: Data, iterations: Int, keyLength: Int) -> Data {
        let hashLength = 32 // SHA256 output size
        let blockCount = Int(ceil(Double(keyLength) / Double(hashLength)))
        let key = SymmetricKey(data: password)
        var output = Data()

        for blockIndex in 1...blockCount {
            var blockIndexBE = UInt32(blockIndex).bigEndian
            var salted = salt
            withUnsafeBytes(of: &blockIndexBE) { salted.append(contentsOf: $0) }

            var u = Data(HMAC<SHA256>.authenticationCode(for: salted, using: key))
            var block = u
            if iterations > 1 {
                for _ in 2...iterations {
                    u = Data(HMAC<SHA256>.authenticationCode(for: u, using: key))
                    block = xor(block, u)
                }
            }
            output.append(block)
        }
        return output.prefix(keyLength)
    }

    private static func xor(_ a: Data, _ b: Data) -> Data {
        Data(zip(a, b).map { $0 ^ $1 })
    }
}

public enum EncryptionError: Error, Equatable {
    case emptyPassword
    case sealingFailed
    case incorrectPasswordOrCorruptData
}
