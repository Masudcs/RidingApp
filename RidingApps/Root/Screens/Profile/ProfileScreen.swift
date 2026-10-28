import SwiftUI

/// Profile tab for both roles. Identity header, driver verification (drivers only), then a menu
/// of history/support links and logout. Pass `riderExtras` for riders or `driverExtras` for
/// drivers; whichever is nil hides its rows (saved places, loyalty, etc. are rider-only).
struct ProfileScreen: View {
    let riderExtras: RiderProfileExtras?
    let driverExtras: DriverProfileExtras?
    let rideHistoryStore: RideHistoryStore
    let onLogout: () -> Void
    @State private var viewModel: ProfileViewModel
    @Environment(\.deleteAccountAction) private var deleteAccountAction

    init(
        user: AppUser,
        verification: DriverVerification?,
        riderExtras: RiderProfileExtras?,
        driverExtras: DriverProfileExtras?,
        rideHistoryStore: RideHistoryStore,
        onLogout: @escaping () -> Void,
        viewModel: ProfileViewModel? = nil
    ) {
        self.riderExtras = riderExtras
        self.driverExtras = driverExtras
        self.rideHistoryStore = rideHistoryStore
        self.onLogout = onLogout
        _viewModel = State(wrappedValue: viewModel ?? ProfileViewModel(user: user, verification: verification))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(viewModel.user.fullName)
                            .font(BrandTypography.title)
                        Text(viewModel.user.phoneNumber)
                            .font(BrandTypography.body)
                            .foregroundStyle(BrandColor.textSecondary)
                        Text(viewModel.ratingSummary)
                            .font(BrandTypography.caption)
                            .foregroundStyle(BrandColor.textSecondary)
                    }
                }
                if let verification = viewModel.verification {
                    Section("Driver Verification") {
                        DriverVerificationBadge(verification: verification, ratingAverage: viewModel.user.ratingAverage)
                    }
                }
                Section {
                    NavigationLink("Ride History") {
                        RideHistoryScreen(userId: viewModel.user.id, store: rideHistoryStore)
                    }
                    NavigationLink("Ratings") {
                        RatingHistoryScreen(userId: viewModel.user.id)
                    }
                    if let riderExtras {
                        NavigationLink("Saved Places") {
                            SavedPlacesScreen(store: riderExtras.savedPlacesStore)
                        }
                        NavigationLink("My Drivers") {
                            FavoriteDriversScreen(store: riderExtras.favoriteDriversStore)
                        }
                        NavigationLink("Loyalty") {
                            LoyaltyScreen(store: riderExtras.loyaltyStore)
                        }
                        NavigationLink("Refer & Earn") {
                            ReferralScreen(store: riderExtras.referralStore) { bonus in
                                await viewModel.creditRiderReferralBonus(bonus)
                            }
                        }
                    }
                    if let driverExtras {
                        NavigationLink("Refer & Earn") {
                            ReferralScreen(store: driverExtras.referralStore) { bonus in
                                await viewModel.creditDriverReferralBonus(bonus)
                            }
                        }
                    }
                    NavigationLink("Help & Support") {
                        SupportCenterScreen(userId: viewModel.user.id, rideHistoryStore: rideHistoryStore)
                    }
                }
                Section {
                    Button(role: .destructive, action: onLogout) {
                        Text("Log Out")
                    }
                    .disabled(viewModel.isDeletingAccount)
                }
                if let deleteAccountAction {
                    // Separate section so it is not tapped by accident next to Log Out.
                    Section {
                        Button(role: .destructive) {
                            viewModel.isConfirmingDelete = true
                        } label: {
                            HStack {
                                Text("Delete Account")
                                Spacer()
                                if viewModel.isDeletingAccount { ProgressView() }
                            }
                        }
                        .disabled(viewModel.isDeletingAccount)
                    } footer: {
                        Text("Permanently deletes your account and the data stored on this device.")
                    }
                    .confirmationDialog(
                        "Delete your account?",
                        isPresented: $viewModel.isConfirmingDelete,
                        titleVisibility: .visible
                    ) {
                        Button("Delete Permanently", role: .destructive) {
                            Task { await viewModel.deleteAccount(using: deleteAccountAction) }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This cannot be undone. Your profile, ride history, saved places, favorite drivers, loyalty points, referral credit, support requests and safety settings will be removed.")
                    }
                }
            }
            .navigationTitle("Profile")
            .alert(
                "Couldn't Delete Account",
                isPresented: Binding(
                    get: { viewModel.deleteErrorMessage != nil },
                    set: { if !$0 { viewModel.deleteErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.deleteErrorMessage ?? "")
            }
        }
    }
}

#if DEBUG

/// A profile screen for one fake user, with stores kept in a private `UserDefaults` suite.
@MainActor
private func previewProfile(
    user: AppUser,
    verification: DriverVerification? = nil,
    isDeleting: Bool = false,
    isError: Bool = false
) -> some View {
    let defaults = UserDefaults(suiteName: "preview.profile")!
    let isRider = user.role == .rider
    return ProfileScreen(
        user: user,
        verification: verification,
        riderExtras: isRider ? RiderProfileExtras(
            savedPlacesStore: SavedPlacesStore(userId: user.id, defaults: defaults),
            favoriteDriversStore: FavoriteDriversStore(userId: user.id, defaults: defaults),
            loyaltyStore: LoyaltyStore(userId: user.id, defaults: defaults),
            referralStore: ReferralStore(userId: user.id, defaults: defaults)
        ) : nil,
        driverExtras: isRider ? nil : DriverProfileExtras(referralStore: ReferralStore(userId: user.id, defaults: defaults)),
        rideHistoryStore: RideHistoryStore(defaults: defaults),
        onLogout: {},
        viewModel: ProfileViewModel(isPreview: true, user: user, verification: verification, isDeleting: isDeleting, isError: isError)
    )
    .environment(\.deleteAccountAction, { false })
}

#Preview("Rider") {
    previewProfile(user: .mockRider(id: "preview-user"))
}

#Preview("Driver - verified") {
    previewProfile(user: .mockDriver(id: "preview-user"), verification: .mock(status: .verified))
}

#Preview("Driver - pending") {
    previewProfile(user: .mockDriver(id: "preview-user"), verification: .mock(status: .pending))
}

#Preview("Driver - rejected") {
    previewProfile(user: .mockDriver(id: "preview-user"), verification: .mock(status: .rejected))
}

#Preview("Deleting account") {
    previewProfile(user: .mockRider(id: "preview-user"), isDeleting: true)
}

#Preview("Delete error") {
    previewProfile(user: .mockRider(id: "preview-user"), isError: true)
}

#Preview("Rider - Dark") {
    previewProfile(user: .mockRider(id: "preview-user"))
        .preferredColorScheme(.dark)
}

#endif
