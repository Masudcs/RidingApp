import Foundation

/// Shared per rider session the same way `RideHistoryStore` is. Keyed by the driver's stable id
/// (not name), since `MockBookingRepository` now gives each pool driver a fixed id specifically so
/// favoriting/blocking can mean something across separate rides. Persisted to `UserDefaults`,
/// keyed by rider, so favorites/blocks survive an app relaunch.
@MainActor
public final class FavoriteDriversStore: ObservableObject {
    /// driverId -> display name. A driver is never in `favorites` and `blocked` at the same time.
    @Published public private(set) var favorites: [String: String]
    @Published public private(set) var blocked: [String: String]

    private let favoritesKey: String
    private let blockedKey: String
    private let defaults: UserDefaults

    public init(userId: String = "", defaults: UserDefaults = .standard) {
        self.favoritesKey = "favoriteDrivers.favorites.\(userId)"
        self.blockedKey = "favoriteDrivers.blocked.\(userId)"
        self.defaults = defaults
        self.favorites = LocalStore.load([String: String].self, forKey: favoritesKey, defaults: defaults) ?? [:]
        self.blocked = LocalStore.load([String: String].self, forKey: blockedKey, defaults: defaults) ?? [:]
    }

    public func isFavorite(_ driverId: String) -> Bool { favorites[driverId] != nil }
    public func isBlocked(_ driverId: String) -> Bool { blocked[driverId] != nil }

    /// Favoriting a blocked driver unblocks them first (and vice versa in `toggleBlocked`).
    public func toggleFavorite(driverId: String, name: String) {
        if favorites[driverId] != nil {
            favorites.removeValue(forKey: driverId)
        } else {
            favorites[driverId] = name
            blocked.removeValue(forKey: driverId)
        }
        persist()
    }

    public func toggleBlocked(driverId: String, name: String) {
        if blocked[driverId] != nil {
            blocked.removeValue(forKey: driverId)
        } else {
            blocked[driverId] = name
            favorites.removeValue(forKey: driverId)
        }
        persist()
    }

    /// Plain id sets, handed to the repository so matching can prefer favorites and skip blocked drivers.
    public var favoriteIds: Set<String> { Set(favorites.keys) }
    public var blockedIds: Set<String> { Set(blocked.keys) }

    private func persist() {
        LocalStore.save(favorites, forKey: favoritesKey, defaults: defaults)
        LocalStore.save(blocked, forKey: blockedKey, defaults: defaults)
    }
}

#if DEBUG

public extension FavoriteDriversStore {
    /// Backed by the throwaway preview suite (see `UserDefaults.bookingPreview()`). Maps are driverId -> name.
    static func mock(
        favorites: [String: String] = ["drv-karim": "Karim Rahman", "drv-nasrin": "Nasrin Akter"],
        blocked: [String: String] = ["drv-selim": "Selim Mia"]
    ) -> FavoriteDriversStore {
        let store = FavoriteDriversStore(userId: "preview-user", defaults: .bookingPreview())
        for (id, name) in favorites {
            store.toggleFavorite(driverId: id, name: name)
        }
        for (id, name) in blocked {
            store.toggleBlocked(driverId: id, name: name)
        }
        return store
    }
}

#endif
