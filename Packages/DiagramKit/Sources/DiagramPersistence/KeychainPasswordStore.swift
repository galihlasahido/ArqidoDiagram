import Foundation
import Security

/// Optional Keychain storage for a document's encryption password (spec
/// §SECURITY: "macOS Keychain") — a user can choose to save the password so
/// they aren't re-prompted on every open, exactly like Keychain-integrated
/// password managers/apps do. Never required: a document opens equally
/// well via a typed password when nothing is saved here.
public enum KeychainPasswordStore {
    private static let service = "com.arqido.ArqidoDiagram.documentPassword"

    public static func save(password: String, for documentID: UUID) {
        let account = documentID.uuidString
        let passwordData = Data(password.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = passwordData
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }

    public static func load(for documentID: UUID) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: documentID.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func delete(for documentID: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: documentID.uuidString
        ]
        SecItemDelete(query as CFDictionary)
    }
}
