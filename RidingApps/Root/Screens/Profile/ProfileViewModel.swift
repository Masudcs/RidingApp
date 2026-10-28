import SwiftUI

/// Grouped since these are all rider-only conveniences — bundling avoids an unwieldy initializer
/// as more of them get added.
struct RiderProfileExtras {
    let savedPlacesStore: SavedPlacesStore
    let favoriteDriversStore: FavoriteDriversStore
    let loyaltyStore: LoyaltyStore
    let referralStore: ReferralStore
}

/// Mirrors `RiderProfileExtras` for the driver-only conveniences.
struct DriverProfileExtras {
    let referralStore: ReferralStore
}

/// State and actions behind the Profile tab, shared by riders and drivers. `user` and
/// `verification` are snapshots taken when the tab is built, so edits made elsewhere don't show
/// here until the parent rebuilds the screen.
@MainActor
@Observable
final class ProfileViewModel {
    let user: AppUser
    /// Non-nil only for drivers; drives the "Driver Verification" section.
    let verification: DriverVerification?

    @ObservationIgnored private let paymentsRepository: IPaymentsRepository
    @ObservationIgnored private let earningsRepository: IDriverEarningsRepository
    @ObservationIgnored private let logger = AppLogger(category: "Profile")
    /// Set only by the debug preview initializer; referral credits never reach a repository.
    @ObservationIgnored private var isPreview = false

    init(
        user: AppUser,
        verification: DriverVerification?,
        paymentsRepository: IPaymentsRepository = PaymentsRepository.makeDefault(),
        earningsRepository: IDriverEarningsRepository = AppEnvironment.current.usesMockServices
            ? MockDriverEarningsRepository.shared
            : DriverEarningsRepository()
    ) {
        self.user = user
        self.verification = verification
        self.paymentsRepository = paymentsRepository
        self.earningsRepository = earningsRepository
    }

    /// True while account deletion is running; the UI shows progress and ignores further taps.
    private(set) var isDeletingAccount = false
    /// Set when `deleteAccount` fails; shown in an alert, cleared by `dismissDeleteError`.
    var deleteErrorMessage: String?
    /// Drives the "are you sure?" confirmation dialog.
    var isConfirmingDelete = false

    /// Runs the delete action once at a time. On failure sets `deleteErrorMessage` and the user
    /// stays signed in; on success the root screen signs out and this screen goes away.
    func deleteAccount(using action: @MainActor () async -> Bool) async {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        let succeeded = await action()
        if !succeeded {
            deleteErrorMessage = String(localized: "We couldn't delete your account. Check your connection and try again. You are still signed in.")
        }
    }

    /// One-line rating text under the user's name, e.g. "4.8 ★ (12 ratings)".
    var ratingSummary: String {
        String(
            format: String(localized: "%.1f \u{2605} (%d ratings)"),
            user.ratingAverage,
            user.ratingCount
        )
    }

    /// Passed to the rider's `ReferralScreen` as its bonus callback. Failures are only logged
    /// because the callback can't report back; the referral screen has already shown the bonus.
    func creditRiderReferralBonus(_ bonus: Money) async {
        guard !isPreview else { return }
        do {
            _ = try await paymentsRepository.topUp(amount: bonus, method: .cash)
        } catch {
            logger.error("Failed to credit rider referral bonus: \(error)")
        }
    }

    /// Driver counterpart: credits the bonus to the driver's earnings balance. Same failure
    /// behaviour as `creditRiderReferralBonus`.
    func creditDriverReferralBonus(_ bonus: Money) async {
        guard !isPreview else { return }
        do {
            _ = try await earningsRepository.creditReferralBonus(amount: bonus)
        } catch {
            logger.error("Failed to credit driver referral bonus: \(error)")
        }
    }
}

/// Environment hook for deleting the signed-in account. `RootScreen` provides it (backend call,
/// local data wipe, sign-out); the Profile tab reads it, so the rider/driver root screens need no
/// extra parameter. Returns true on success. Nil (the default) hides the Delete account row.
private struct DeleteAccountActionKey: EnvironmentKey {
    static let defaultValue: (@MainActor () async -> Bool)? = nil
}

extension EnvironmentValues {
    var deleteAccountAction: (@MainActor () async -> Bool)? {
        get { self[DeleteAccountActionKey.self] }
        set { self[DeleteAccountActionKey.self] = newValue }
    }
}

#if DEBUG

extension ProfileViewModel {
    /// Fixed fake profile with mock repositories. `isDeleting` shows the account-deletion spinner and
    /// `isError` the failure alert. `isPreview` has no default to keep init calls explicit.
    convenience init(
        isPreview: Bool,
        user: AppUser,
        verification: DriverVerification? = nil,
        isDeleting: Bool = false,
        isError: Bool = false
    ) {
        self.init(
            user: user,
            verification: verification,
            paymentsRepository: MockPaymentsRepository.shared,
            earningsRepository: MockDriverEarningsRepository.shared
        )
        self.isPreview = isPreview
        self.isDeletingAccount = isDeleting
        self.deleteErrorMessage = isError ? String(localized: "We couldn't delete your account. Check your connection and try again. You are still signed in.") : nil
    }
}

#endif
