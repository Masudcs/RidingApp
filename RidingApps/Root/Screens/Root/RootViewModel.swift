import SwiftUI

/// Holds the app-wide login state for `RootScreen`: who is signed in (if anyone) and, for drivers,
/// their identity-verification status. It is the only place that talks to `SessionStore`, so the
/// rest of the app never touches the stored session directly.
///
/// Lifecycle:
/// - app launch      -> `restoreSession()` brings back the previous login
/// - login / sign-up -> `didAuthenticate(...)` stores the new login
/// - logout / account deleted -> `logOut()` forgets it
///
/// `RootScreen` observes `currentUser`: non-nil shows the rider/driver flow, nil shows login.
@MainActor
@Observable
final class RootViewModel {
    /// The signed-in user, or nil when logged out. Read-only outside this class so state
    /// can only change through the methods below (which keep the saved session in sync).
    private(set) var currentUser: AppUser?
    /// Only meaningful for drivers; nil for riders or before verification is submitted.
    private(set) var driverVerification: DriverVerification?

    /// Not observed by SwiftUI: the store never changes in a way the UI needs to react to.
    @ObservationIgnored private let sessionStore: SessionStore

    @ObservationIgnored private let authRepository: IAuthRepository
    /// Where per-user local data lives; injectable so tests don't touch `UserDefaults.standard`.
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let logger = AppLogger(category: "Root")

    /// Bumped after a successful account deletion so `RootScreen` can reload stores that keep
    /// in-memory copies of data (e.g. ride history) from the now-cleaned `UserDefaults`.
    private(set) var localDataResetCount = 0

    /// Set only by the debug preview initializer; stops account deletion reaching the backend.
    @ObservationIgnored private var isPreview = false

    /// Inject a store with a test service name (and a throwaway repository/defaults) in tests;
    /// the app uses the defaults.
    init(
        sessionStore: SessionStore = SessionStore(),
        authRepository: IAuthRepository = AuthRepositoryFactory.make(),
        defaults: UserDefaults = .standard
    ) {
        self.sessionStore = sessionStore
        self.authRepository = authRepository
        self.defaults = defaults
        // A rejected token refresh means the session is over: sign out (the callback may come from any thread).
        APIClientFactory.setSessionExpiredHandler { [weak self] in
            Task { @MainActor in self?.onSessionExpired() }
        }
    }

    /// The API said the session can't be renewed any more (refresh token rejected).
    func onSessionExpired() {
        guard currentUser != nil else { return }
        logger.info("Session expired; logging out")
        logOut()
    }

    /// Restores the saved login at launch so the user isn't asked to sign in again.
    /// Does nothing if someone is already signed in (`onAppear` can fire more than once),
    /// or if nothing usable is saved (the user then sees the login screen).
    ///
    /// TODO(real API): after restoring, refresh the access token if expired and re-fetch the
    /// profile; call `logOut()` if the server rejects the refresh token (401).
    func restoreSession() {
        guard currentUser == nil, let restored = sessionStore.load() else { return }
        currentUser = restored.user
        driverVerification = restored.driverVerification
    }

    /// Called by the auth flow after a successful login or sign-up.
    /// Updates the UI state first, then saves it so the login survives relaunch.
    /// - Parameter tokens: the API tokens from the login response; omit while using the mock
    ///   backend. Omitting keeps any tokens already stored.
    func didAuthenticate(user: AppUser, verification: DriverVerification?, tokens: SessionTokens? = nil) {
        currentUser = user
        driverVerification = verification
        if sessionStore.save(user: user, driverVerification: verification, tokens: tokens) {
            // Now stored for real; drop the in-memory copy used during sign-up.
            SessionTokenProvider.setPendingTokens(nil)
        }
    }

    /// A driver's verification status changed (e.g. pending -> verified). Updates the UI and saves
    /// it, so the driver doesn't land on the "in review" screen again after a relaunch.
    func didUpdateDriverVerification(_ verification: DriverVerification) {
        guard let user = currentUser, user.role == .driver else { return }
        driverVerification = verification
        sessionStore.save(user: user, driverVerification: verification)
    }

    /// Signs out. Also use after the account has been deleted on the server.
    /// Clears memory and the saved session; `RootScreen` then returns to the login screen.
    /// Safe to call when already logged out.
    func logOut() {
        currentUser = nil
        driverVerification = nil
        sessionStore.clear()
        SessionTokenProvider.setPendingTokens(nil)
    }

    /// Permanently deletes the signed-in account: asks the backend first, and only if that
    /// succeeds wipes this user's local data and signs out. Returns false (and leaves the user
    /// signed in with all data intact) when nobody is signed in or the backend call fails.
    func deleteAccount() async -> Bool {
        guard !isPreview else { return false }
        guard let user = currentUser else { return false }
        do {
            try await authRepository.deleteAccount(userId: user.id)
        } catch {
            logger.error("Account deletion failed for user \(user.id): \(error)")
            return false
        }
        eraseLocalData(for: user)
        logOut()
        localDataResetCount += 1
        return true
    }

    /// Removes everything this device stored for `user`: all `userId`-keyed stores, their rows in
    /// the shared ride-history list, and the device-wide Silent SOS settings.
    private func eraseLocalData(for user: AppUser) {
        LocalStore.removeAll(forUserId: user.id, defaults: defaults)
        // Ride history is one shared list for every account on the device; drop only this owner's rows.
        let historyKey = "rideHistory.entries"
        if let entries = LocalStore.load([RideHistoryEntry].self, forKey: historyKey, defaults: defaults) {
            LocalStore.save(entries.filter { $0.ownerId != user.id }, forKey: historyKey, defaults: defaults)
        }
        for key in ["SilentSOS.isEnabled", "SilentSOS.codeword"] {
            LocalStore.remove(forKey: key, defaults: defaults)
        }
    }
}

#if DEBUG

extension RootViewModel {
    /// Fixed fake login (or logged out when `user` is nil) backed by a private `UserDefaults`
    /// suite and a mock repository. `isPreview` has no default so a plain `init()` stays unambiguous.
    convenience init(isPreview: Bool, user: AppUser? = nil, verification: DriverVerification? = nil) {
        let defaults = UserDefaults(suiteName: "preview.root")!
        self.init(
            sessionStore: SessionStore(service: "preview.session", defaults: defaults),
            authRepository: MockAuthRepository(),
            defaults: defaults
        )
        self.isPreview = isPreview
        self.currentUser = user
        self.driverVerification = verification
    }
}

#endif
