import Foundation

/// Where a trip is in its lifecycle, plus the payloads that stage needs to be shown again.
/// Saved as one JSON value so a relaunch mid-trip can land on the same screen.
public struct TripStageSnapshot: Codable, Equatable, Sendable {
    public enum Stage: String, Codable, Sendable {
        /// Driver matched, trip running.
        case active
        /// Rider only: trip finished, waiting for payment.
        case awaitingPayment
        /// Trip finished, waiting for the rating (rider rates driver or driver rates rider).
        case awaitingRating
        /// Rider only: paid and rated, receipt on screen.
        case receipt
    }

    public let stage: Stage
    public let trip: Trip?
    public let receipt: PaymentReceipt?
    public let savedAt: Date

    public init(stage: Stage, trip: Trip?, receipt: PaymentReceipt? = nil, savedAt: Date = Date()) {
        self.stage = stage
        self.trip = trip
        self.receipt = receipt
        self.savedAt = savedAt
    }

    /// When the trip began, used to detect stale data. The receipt stage may have no trip, so it
    /// falls back to the receipt time.
    var startedAt: Date? {
        if let trip { return trip.driverAssignedAt ?? trip.createdAt }
        return receipt?.createdAt
    }

    /// True when the stage has the payload its screen needs.
    var isComplete: Bool {
        switch stage {
        case .active, .awaitingPayment, .awaitingRating: return trip != nil
        case .receipt: return receipt != nil
        }
    }
}

/// Saves the current trip stage per user and role in UserDefaults so it survives an app kill.
///
/// This is a stand-in for the server. TODO(real API): once the backend exists, the server is the
/// source of truth for the active trip; replace `load` with a repository call (for example
/// "current trip for user") and keep this only as an offline cache, or remove it.
public struct TripStageStore {
    public enum Role: String, Sendable, CaseIterable {
        case rider
        case driver
    }

    /// Snapshots whose trip started longer ago than this are dropped (12 hours).
    public static let maxTripAge: TimeInterval = 12 * 60 * 60

    private static let logger = AppLogger(category: "TripStageStore")

    private let defaults: UserDefaults
    private let now: () -> Date

    /// `defaults` and `now` are injectable for tests.
    public init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
    }

    /// Overwrites the saved stage for this user and role.
    public func save(_ snapshot: TripStageSnapshot, role: Role, userId: String) {
        LocalStore.save(snapshot, forKey: Self.key(role: role, userId: userId), defaults: defaults)
    }

    /// Returns the saved stage, or nil if there is none. Corrupt, incomplete or stale data is
    /// removed and nil is returned; this never throws.
    public func load(role: Role, userId: String) -> TripStageSnapshot? {
        let key = Self.key(role: role, userId: userId)
        guard defaults.data(forKey: key) != nil else { return nil }
        guard let snapshot = LocalStore.load(TripStageSnapshot.self, forKey: key, defaults: defaults) else {
            Self.logger.error("Discarding unreadable saved trip stage")
            discard(key: key)
            return nil
        }
        guard snapshot.isComplete, let startedAt = snapshot.startedAt else {
            Self.logger.error("Discarding incomplete saved trip stage")
            discard(key: key)
            return nil
        }
        if now().timeIntervalSince(startedAt) > Self.maxTripAge {
            Self.logger.info("Discarding stale saved trip stage")
            discard(key: key)
            return nil
        }
        return snapshot
    }

    /// Forgets the saved stage for one user and role (the trip cycle ended).
    public func clear(role: Role, userId: String) {
        discard(key: Self.key(role: role, userId: userId))
    }

    /// Forgets everything saved for this user, for both roles. Call it on logout or account wipe.
    public func clear(for userId: String) {
        for role in Role.allCases {
            clear(role: role, userId: userId)
        }
    }

    private func discard(key: String) {
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: key + ".corrupt")
    }

    private static func key(role: Role, userId: String) -> String {
        "tripStage.\(role.rawValue).\(userId)"
    }
}
