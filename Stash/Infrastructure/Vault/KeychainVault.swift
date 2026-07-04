import Foundation
import Security
import LocalAuthentication

enum KeychainVaultError: Error, Equatable {
    case storeFailed(OSStatus)
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)
    case userCancelled
    case notFound
}

final class KeychainVault {
    private let service: String

    init(service: String = "com.soi.stash.vault") {
        self.service = service
    }

    func store(id: UUID, secret: Data) throws {
        try delete(id: id, silent: true)
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
            kSecValueData as String: secret,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        if let access = makeAccessControl() {
            query[kSecAttrAccessControl as String] = access
            query.removeValue(forKey: kSecAttrAccessible as String)
        }
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainVaultError.storeFailed(status)
        }
    }

    func reveal(id: UUID, reason: String, context: LAContext = LAContext()) throws -> Data {
        context.localizedReason = reason
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
            kSecReturnData as String: true,
            kSecUseAuthenticationContext as String: context
        ]
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                throw KeychainVaultError.readFailed(status)
            }
            return data
        case errSecUserCanceled, errSecAuthFailed:
            throw KeychainVaultError.userCancelled
        case errSecItemNotFound:
            throw KeychainVaultError.notFound
        default:
            throw KeychainVaultError.readFailed(status)
        }
    }

    func delete(id: UUID, silent: Bool = false) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound { return }
        if !silent { throw KeychainVaultError.deleteFailed(status) }
    }

    private func makeAccessControl() -> SecAccessControl? {
        var error: Unmanaged<CFError>?
        let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .userPresence,
            &error
        )
        return access
    }
}
