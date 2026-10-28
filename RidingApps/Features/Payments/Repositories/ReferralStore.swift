import Foundation

/// Shared per session like the other stores — used by both riders and drivers, since the
/// redeem/credit mechanics are identical, only where the bonus lands differs. `myCode` is derived
/// once from the user's id so it's stable for the session without needing any backend to issue it.
/// Redeemed codes and earned credit are persisted to `UserDefaults`, keyed by user, so they
/// survive an app relaunch.
@MainActor
public final class ReferralStore: ObservableObject {
    /// Why `redeem` refused a code.
    public enum RedeemError: Error, Equatable, Sendable {
        case invalidCode
        case ownCode
        case alreadyRedeemed
    }

    /// What is saved to `UserDefaults` for this user.
    private struct StoredState: Codable {
        var redeemedCodes: [String]
        var creditEarnedMinorUnits: Int
    }

    /// This user's shareable code, "RIDE-" plus the first 6 characters of their id.
    public let myCode: String
    @Published public private(set) var redeemedCodes: [String] = []
    @Published public private(set) var creditEarned: Money = Money(minorUnits: 0)

    /// Credit given for each redeemed code.
    public static let referralBonus = Money.bdt(50)

    private let storageKey: String
    private let defaults: UserDefaults

    public init(userId: String, defaults: UserDefaults = .standard) {
        let suffix = userId.replacingOccurrences(of: "-", with: "").prefix(6).uppercased()
        self.myCode = "RIDE-\(suffix)"
        self.storageKey = "referral.state.\(userId)"
        self.defaults = defaults
        if let stored = LocalStore.load(StoredState.self, forKey: storageKey, defaults: defaults) {
            self.redeemedCodes = stored.redeemedCodes
            self.creditEarned = Money(minorUnits: stored.creditEarnedMinorUnits)
        }
    }

    /// Validates and records a friend's code, and returns the bonus to credit. Checks are local
    /// only (empty, own code, already used); there is no server check that the code exists.
    /// The caller is responsible for actually adding the returned credit to the wallet.
    @discardableResult
    public func redeem(_ code: String) throws -> Money {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { throw RedeemError.invalidCode }
        guard trimmed != myCode else { throw RedeemError.ownCode }
        guard !redeemedCodes.contains(trimmed) else { throw RedeemError.alreadyRedeemed }

        redeemedCodes.append(trimmed)
        creditEarned = creditEarned + Self.referralBonus
        persist()
        Analytics.track("referral_redeemed")
        return Self.referralBonus
    }

    /// Writes redeemed codes and credit to `UserDefaults`.
    private func persist() {
        let stored = StoredState(redeemedCodes: redeemedCodes, creditEarnedMinorUnits: creditEarned.minorUnits)
        LocalStore.save(stored, forKey: storageKey, defaults: defaults)
    }
}

#if DEBUG

public extension ReferralStore {
    /// Throwaway store for previews: its own user id and defaults suite, so no real user's referral state is touched.
    static func mock(redeemedCodes: [String] = [], creditEarned: Money = .bdt(0)) -> ReferralStore {
        let store = ReferralStore(userId: "preview-user", defaults: UserDefaults(suiteName: "preview.referral") ?? .standard)
        store.redeemedCodes = redeemedCodes
        store.creditEarned = creditEarned
        return store
    }
}

#endif
