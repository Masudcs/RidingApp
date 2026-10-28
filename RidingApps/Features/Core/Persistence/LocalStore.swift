import Foundation

/// Thin JSON-over-UserDefaults helper for the app's lightweight, non-sensitive local stores.
/// Session credentials live in `SessionStore` (also UserDefaults, one key); this is for data that is fine
/// surviving in UserDefaults so it doesn't vanish on every relaunch (loyalty points, saved
/// places, ride history, ...). `defaults` is injectable so tests don't have to touch the real
/// `UserDefaults.standard` suite.
public enum LocalStore {
    private static let logger = AppLogger(category: "LocalStore")

    /// Returns nil when nothing is stored. If stored data no longer decodes (e.g. a model
    /// changed between app versions), it is copied to `<key>.corrupt` before returning nil, so
    /// the next `save` doesn't destroy the only copy.
    public static func load<T: Decodable>(_ type: T.Type, forKey key: String, defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            logger.error("Failed to decode \(key): \(error)")
            defaults.set(data, forKey: key + ".corrupt")
            return nil
        }
    }

    /// Overwrites any existing value. An encoding failure is logged and leaves the old value.
    public static func save<T: Encodable>(_ value: T, forKey key: String, defaults: UserDefaults) {
        do {
            defaults.set(try JSONEncoder().encode(value), forKey: key)
        } catch {
            logger.error("Failed to encode \(key): \(error)")
        }
    }

    /// Removes every key whose name contains `userId` (e.g. `savedPlaces.<id>`, plus its
    /// `.corrupt` backup), so one account's data goes without touching other accounts. Does
    /// nothing for an empty id, which would otherwise match every key. Returns the removed keys.
    @discardableResult
    public static func removeAll(forUserId userId: String, defaults: UserDefaults) -> [String] {
        guard !userId.isEmpty else { return [] }
        let keys = defaults.dictionaryRepresentation().keys.filter { $0.contains(userId) }
        for key in keys { defaults.removeObject(forKey: key) }
        return Array(keys)
    }

    /// Removes a single key (and its `.corrupt` backup). For device-wide keys that are not
    /// namespaced by user id.
    public static func remove(forKey key: String, defaults: UserDefaults) {
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: key + ".corrupt")
    }
}
