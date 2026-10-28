import SwiftUI

/// The app's top-level screen. It only decides WHICH flow to show:
/// - not logged in -> `AuthFlowScreen` (login / sign up)
/// - logged in as rider -> `RiderRootScreen`
/// - logged in as driver -> `DriverRootScreen`
/// Login state lives in `RootViewModel`, which saves/restores it through `SessionStore`.
struct RootScreen: View {
    @State private var viewModel: RootViewModel
    /// Created once here and shared with both rider and driver flows (one GPS source for the app).
    @State private var locationProvider = LocationProvider()
    /// Shared ride history, also passed down to both flows.
    @State private var rideHistoryStore = RideHistoryStore()

    /// Pass a custom view model in previews/tests; the app itself uses the default one.
    init(viewModel: RootViewModel? = nil) {
        _viewModel = State(wrappedValue: viewModel ?? RootViewModel())
    }

    var body: some View {
        // Swaps the whole screen whenever `currentUser` changes: logging in shows the rider/driver
        // flow, logging out (currentUser = nil) returns to the auth flow automatically.
        Group {
            if let user = viewModel.currentUser {
                switch user.role {
                case .rider:
                    RiderRootScreen(
                        rider: user,
                        locationProvider: locationProvider,
                        rideHistoryStore: rideHistoryStore,
                        onLogout: viewModel.logOut
                    )
                case .driver:
                    DriverRootScreen(
                        driver: user,
                        verification: viewModel.driverVerification,
                        locationProvider: locationProvider,
                        rideHistoryStore: rideHistoryStore,
                        onVerificationUpdated: viewModel.didUpdateDriverVerification,
                        onLogout: viewModel.logOut
                    )
                }
            } else {
                // Called when login/sign-up succeeds; the view model stores the session.
                AuthFlowScreen { user, verification, tokens in
                    viewModel.didAuthenticate(user: user, verification: verification, tokens: tokens)
                }
            }
        }
        // On launch, load the saved login so the user isn't asked to sign in again.
        .onAppear { viewModel.restoreSession() }
        // Lets the Profile tab (anywhere below) delete the account without extra plumbing.
        .environment(\.deleteAccountAction, { await viewModel.deleteAccount() })
        // Ride history keeps an in-memory copy; reload it after a deletion wiped the saved one.
        .onChange(of: viewModel.localDataResetCount) { rideHistoryStore = RideHistoryStore() }
        // Ask for location and notification permission once, when the app first shows.
        .task {
            #if DEBUG
            // Previews must not trigger the location or notification permission prompts.
            guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
            #endif
            locationProvider.requestPermission()
            LocalNotifications.requestAuthorization()
        }
    }
}

#if DEBUG

#Preview("Logged out") {
    RootScreen(viewModel: RootViewModel(isPreview: true))
}

#Preview("Rider") {
    RootScreen(viewModel: RootViewModel(isPreview: true, user: .mockRider(id: "preview-user")))
}

#Preview("Driver - verified") {
    RootScreen(viewModel: RootViewModel(
        isPreview: true,
        user: .mockDriver(id: "preview-user"),
        verification: .mock(status: .verified)
    ))
}

#Preview("Driver - pending") {
    RootScreen(viewModel: RootViewModel(
        isPreview: true,
        user: .mockDriver(id: "preview-user"),
        verification: .mock(status: .pending)
    ))
}

#Preview("Rider - Dark") {
    RootScreen(viewModel: RootViewModel(isPreview: true, user: .mockRider(id: "preview-user")))
        .preferredColorScheme(.dark)
}

#endif
