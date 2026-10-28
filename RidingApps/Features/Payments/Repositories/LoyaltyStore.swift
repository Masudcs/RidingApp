import Foundation

/// Shared per rider session the same way `RideHistoryStore` is: points earned at checkout need to
/// be visible immediately from the Loyalty screen. Persisted to `UserDefaults`, keyed by rider,
/// so points aren't wiped out every time the app relaunches.
@MainActor
public final class LoyaltyStore: ObservableObject {
    /// Lifetime points. They only go up; there is no redeeming yet.
    @Published public private(set) var points: Int

    private let storageKey: String
    private let defaults: UserDefaults

    public init(userId: String = "", defaults: UserDefaults = .standard) {
        self.storageKey = "loyalty.points.\(userId)"
        self.defaults = defaults
        self.points = LocalStore.load(Int.self, forKey: storageKey, defaults: defaults) ?? 0
    }

    /// Current tier, derived from `points`.
    public var tier: LoyaltyTier { LoyaltyTier.tier(for: points) }

    /// 1 point per ৳10 spent, with a 5-point floor so even short rides earn something.
    /// Called once per completed payment; it doesn't check for repeats, so callers must not
    /// call it twice for the same receipt.
    public func awardPoints(for fare: Money) {
        // Integer math: ৳10 = 1000 minor units (rounds down, same as before).
        points += max(5, fare.minorUnits / 1000)
        LocalStore.save(points, forKey: storageKey, defaults: defaults)
    }
}

#if DEBUG

public extension LoyaltyStore {
    /// Throwaway store for previews: its own user id and defaults suite, so no real rider's points are touched.
    static func mock(points: Int = 320) -> LoyaltyStore {
        let store = LoyaltyStore(userId: "preview-user", defaults: UserDefaults(suiteName: "preview.loyalty") ?? .standard)
        store.points = points
        return store
    }
}

#endif
