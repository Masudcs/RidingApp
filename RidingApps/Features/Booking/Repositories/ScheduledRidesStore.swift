import Foundation

/// Shared the same way `RideHistoryStore` is: owned once by the rider's root view so a ride
/// scheduled from the booking flow is immediately visible from anywhere that reads it. Persisted
/// to `UserDefaults`, keyed by rider, so a scheduled ride survives an app relaunch.
@MainActor
public final class ScheduledRidesStore: ObservableObject {
    @Published public private(set) var rides: [ScheduledRide]

    private let storageKey: String
    private let defaults: UserDefaults

    public init(userId: String = "", defaults: UserDefaults = .standard) {
        self.storageKey = "scheduledRides.\(userId)"
        self.defaults = defaults
        self.rides = LocalStore.load([ScheduledRide].self, forKey: storageKey, defaults: defaults) ?? []
    }

    /// Keeps `rides` sorted soonest first.
    public func add(_ ride: ScheduledRide) {
        rides.append(ride)
        rides.sort { $0.scheduledFor < $1.scheduledFor }
        persist()
    }

    public func remove(id: String) {
        rides.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        LocalStore.save(rides, forKey: storageKey, defaults: defaults)
    }
}

#if DEBUG

public extension ScheduledRidesStore {
    /// Backed by the throwaway preview suite (see `UserDefaults.bookingPreview()`).
    static func mock(rides: [ScheduledRide] = ScheduledRide.mockList()) -> ScheduledRidesStore {
        let store = ScheduledRidesStore(userId: "preview-user", defaults: .bookingPreview())
        for ride in rides {
            store.add(ride)
        }
        return store
    }
}

#endif
