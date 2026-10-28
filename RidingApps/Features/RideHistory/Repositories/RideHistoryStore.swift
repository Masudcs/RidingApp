import Foundation
import Observation

/// Shared across the app the same way `LocationProvider` is: created once in the root view and
/// injected via `.environment`, so a trip recorded when it completes is immediately visible
/// from the Profile tab's history list without a network round-trip. Persisted to `UserDefaults`
/// so history survives an app relaunch — it already stores entries for both roles, filtered by
/// `ownerId` on read, so a single global key is enough.
@MainActor
@Observable
public final class RideHistoryStore {
    /// All saved entries (every user on this device), newest recorded first.
    public private(set) var entries: [RideHistoryEntry]

    private static let storageKey = "rideHistory.entries"
    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let loaded = LocalStore.load([RideHistoryEntry].self, forKey: Self.storageKey, defaults: defaults) {
            self.entries = loaded
        } else {
            self.entries = []
            // Data exists but didn't decode (e.g. the model changed). Keep a copy instead of
            // letting the next `record` overwrite it, so it can be recovered or migrated.
            if let raw = defaults.data(forKey: Self.storageKey) {
                defaults.set(raw, forKey: Self.storageKey + ".undecodable")
            }
        }
    }

    /// Adds a finished trip at the top and saves. Recording the same trip for the same user twice
    /// (e.g. a repeated completion callback) is ignored so the list doesn't show duplicates.
    public func record(_ entry: RideHistoryEntry) {
        guard !entries.contains(where: { $0.ownerId == entry.ownerId && $0.tripId == entry.tripId }) else { return }
        entries.insert(entry, at: 0)
        LocalStore.save(entries, forKey: Self.storageKey, defaults: defaults)
    }

    /// One user's entries, most recent first. The store holds both roles, so this filters by owner.
    public func history(forUserId userId: String) -> [RideHistoryEntry] {
        entries
            .filter { $0.ownerId == userId }
            .sorted { $0.completedAt > $1.completedAt }
    }
}

#if DEBUG

extension RideHistoryStore {
    /// Preview store backed by a throwaway `UserDefaults` suite that is wiped on creation, so it
    /// never touches the real history key and previews don't leak entries into each other.
    static func mock(entries: [RideHistoryEntry] = RideHistoryEntry.mockList()) -> RideHistoryStore {
        let suiteName = "RidingApps.preview.rideHistory"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = RideHistoryStore(defaults: defaults)
        entries.reversed().forEach { store.record($0) }
        return store
    }
}

#endif
