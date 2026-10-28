import Foundation
import Security

/// Wraps a single 256-bit symmetric key in the Keychain under a fixed account/service pair.
/// The key must survive app reinstalls-within-a-restore and app-launch-to-app-launch, which is
/// exactly what kSecClassGenericPassword storage (rather than UserDefaults/file storage) gives us
/// for free, without us having to reason about data-protection classes ourselves.
public final class TripRecordingKeyStore {
    private let service = "com.ridehailing.app.tripRecording"
    private let account = "trip-recording-encryption-key"

    public init() {}

    /// Returns the stored key, creating and saving a new one on first use. Throws if the
    /// Keychain is unavailable; callers must not fall back to unencrypted storage.
    public func loadOrCreateKeyData() throws -> Data {
        if let existing = try readKeyData() {
            return existing
        }
        var newKeyBytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, newKeyBytes.count, &newKeyBytes)
        guard status == errSecSuccess else {
            throw NSError(domain: "TripRecordingKeyStore", code: Int(status))
        }
        let newKeyData = Data(newKeyBytes)
        try store(newKeyData)
        return newKeyData
    }

    private func readKeyData() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess {
            return result as? Data
        } else if status == errSecItemNotFound {
            return nil
        } else {
            throw NSError(domain: "TripRecordingKeyStore", code: Int(status))
        }
    }

    /// Replaces any existing item. `AfterFirstUnlock` lets recording finish if the phone locks
    /// mid-trip.
    private func store(_ data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "TripRecordingKeyStore", code: Int(status))
        }
    }
}
