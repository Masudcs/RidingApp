import SwiftUI

/// The signed-in rider's main screen: a tab bar with Ride, Wallet, Safety and Profile.
/// Created by `RootScreen` when the logged-in user's role is `.rider`.
///
/// It creates the rider's data stores once (in `RiderRootViewModel`) and hands the same instances
/// to every tab, so for example a place saved in Profile shows up in the booking screen.
struct RiderRootScreen: View {
    /// Shared with the driver flow too; created once in `RootScreen`.
    let locationProvider: LocationProvider
    let rideHistoryStore: RideHistoryStore
    /// Passed down to the Profile tab's log out button; ends up in `RootViewModel.logOut`.
    let onLogout: () -> Void
    @State private var viewModel: RiderRootViewModel

    /// `@State` keeps the first view model for the whole login, so the stores are not recreated
    /// when SwiftUI rebuilds this view. A fresh `rider` is only read on the next login.
    init(
        rider: AppUser,
        locationProvider: LocationProvider,
        rideHistoryStore: RideHistoryStore,
        onLogout: @escaping () -> Void
    ) {
        self.locationProvider = locationProvider
        self.rideHistoryStore = rideHistoryStore
        self.onLogout = onLogout
        _viewModel = State(wrappedValue: RiderRootViewModel(rider: rider))
    }

    var body: some View {
        TabView {
            // Booking and the whole trip lifecycle (book, track, pay, rate).
            RiderHomeScreen(
                rider: viewModel.rider,
                savedPlacesStore: viewModel.savedPlacesStore,
                scheduledRidesStore: viewModel.scheduledRidesStore,
                favoriteDriversStore: viewModel.favoriteDriversStore,
                loyaltyStore: viewModel.loyaltyStore,
                locationProvider: locationProvider,
                rideHistoryStore: rideHistoryStore
            )
                .tabItem { Label("Ride", systemImage: "car.fill") }
            // Payment methods and promo codes; has no inputs because it manages its own data.
            WalletScreen()
                .tabItem { Label("Wallet", systemImage: "wallet.pass.fill") }
            // Emergency contacts and safety settings.
            SafetyTabScreen()
                .tabItem { Label("Safety", systemImage: "shield.fill") }
            // Shared Profile screen; riders pass `riderExtras` and no driver data
            // (`verification` and `driverExtras` are driver-only).
            ProfileScreen(
                user: viewModel.rider,
                verification: nil,
                riderExtras: RiderProfileExtras(
                    savedPlacesStore: viewModel.savedPlacesStore,
                    favoriteDriversStore: viewModel.favoriteDriversStore,
                    loyaltyStore: viewModel.loyaltyStore,
                    referralStore: viewModel.referralStore
                ),
                driverExtras: nil,
                rideHistoryStore: rideHistoryStore,
                onLogout: onLogout
            )
                .tabItem { Label("Profile", systemImage: "person.circle.fill") }
        }
        .tint(BrandColor.primary)
    }
}

#if DEBUG

#Preview("Rider tabs") {
    RiderRootScreen(
        rider: .mockRider(id: "preview-user"),
        locationProvider: LocationProvider(),
        rideHistoryStore: RideHistoryStore(defaults: UserDefaults(suiteName: "preview.riderRoot")!),
        onLogout: {}
    )
}

#Preview("Rider tabs - Dark") {
    RiderRootScreen(
        rider: .mockRider(id: "preview-user"),
        locationProvider: LocationProvider(),
        rideHistoryStore: RideHistoryStore(defaults: UserDefaults(suiteName: "preview.riderRoot")!),
        onLogout: {}
    )
    .preferredColorScheme(.dark)
}

#endif
