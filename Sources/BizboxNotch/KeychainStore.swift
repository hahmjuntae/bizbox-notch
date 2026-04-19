import Foundation
import Security

final class KeychainStore: @unchecked Sendable {
    static let shared = KeychainStore()

    private let service = "com.hahmjuntae.bizbox-notch"

    func read(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func save(_ value: String, account: String) {
        var query = baseQuery(account: account)
        SecItemDelete(query as CFDictionary)

        guard let data = value.data(using: .utf8) else {
            return
        }

        query[kSecValueData as String] = data
        SecItemAdd(query as CFDictionary, nil)
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
