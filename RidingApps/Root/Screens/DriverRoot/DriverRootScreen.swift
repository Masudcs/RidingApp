import SwiftUI

/// Driver-side root. Shows the tab bar once verification is approved, otherwise a status screen
/// (waiting, or rejected) with a logout button.
///
/// While the review is pending, the status screen re-checks with the backend every few seconds and
/// has a "Check status" button. When the driver is approved the screen switches to the tabs by itself.
///
/// Tabs: Home (go online, accept and run trips), Heatmap (where demand is), Earnings (and cash out),
/// Safety, Profile.
struct DriverRootScreen: View {
    /// Shared with the rider flow; created once in `RootScreen`.
    let locationProvider: LocationProvider
    let rideHistoryStore: RideHistoryStore
    /// Passed to the Profile tab's log out button and to the status screen's log out button.
    let onLogout: () -> Void
    @State private var viewModel: DriverRootViewModel

    /// - Parameter onVerificationUpdated: called when the review result changes so the caller can
    ///   save it (see `RootViewModel.didUpdateDriverVerification`).
    init(
        driver: AppUser,
        verification: DriverVerification?,
        locationProvider: LocationProvider,
        rideHistoryStore: RideHistoryStore,
        onVerificationUpdated: @escaping (DriverVerification) -> Void = { _ in },
        onLogout: @escaping () -> Void,
        viewModel: DriverRootViewModel? = nil
    ) {
        self.locationProvider = locationProvider
        self.rideHistoryStore = rideHistoryStore
        self.onLogout = onLogout
        _viewModel = State(wrappedValue: viewModel ?? DriverRootViewModel(
            driver: driver,
            verification: verification,
            onVerificationUpdated: onVerificationUpdated
        ))
    }

    var body: some View {
        if viewModel.isVerified {
            TabView {
                // Go online, receive requests, run the active trip.
                DriverHomeScreen(
                    driver: viewModel.driver,
                    locationProvider: locationProvider,
                    rideHistoryStore: rideHistoryStore
                )
                    .tabItem { Label("Home", systemImage: "steeringwheel") }
                // Shows where rider demand is high.
                DemandHeatmapScreen()
                    .tabItem { Label("Heatmap", systemImage: "flame.fill") }
                // Earnings summary, incentives and cash out.
                DriverEarningsDashboardScreen()
                    .tabItem { Label("Earnings", systemImage: "banknote.fill") }
                SafetyTabScreen()
                    .tabItem { Label("Safety", systemImage: "shield.fill") }
                // Shared Profile screen; drivers pass `driverExtras` and their verification record.
                ProfileScreen(
                    user: viewModel.driver,
                    verification: viewModel.verification,
                    riderExtras: nil,
                    driverExtras: DriverProfileExtras(referralStore: viewModel.referralStore),
                    rideHistoryStore: rideHistoryStore,
                    onLogout: onLogout
                )
                    .tabItem { Label("Profile", systemImage: "person.circle.fill") }
            }
            .tint(BrandColor.primary)
        } else {
            Group {
                if viewModel.isResubmitting {
                    resubmitScreen
                } else {
                    reviewStatusScreen
                }
            }
            // `.task` is cancelled when this screen goes away, which stops the polling loop.
            // The id restarts it when the status changes (e.g. rejected -> pending after resubmitting).
            .task(id: viewModel.verification?.status) { await viewModel.pollUntilDecided() }
        }
    }

    /// Shown instead of the tabs until the driver is approved. Wording depends on the status.
    private var reviewStatusScreen: some View {
        let isRejected = viewModel.verification?.status == .rejected
        return VStack(spacing: 20) {
            Image(systemName: isRejected ? "xmark.seal.fill" : "clock.badge.checkmark")
                .font(.system(size: 56))
                .foregroundStyle(isRejected ? BrandColor.danger : BrandColor.warning)
            Text(isRejected ? "Verification not approved" : "Verification in review")
                .font(BrandTypography.title)
            if let verification = viewModel.verification {
                DriverVerificationBadge(verification: verification, ratingAverage: viewModel.driver.ratingAverage)
            }
            Text(isRejected
                 ? "We couldn't verify your NID and driving license. You can resubmit your documents or contact support."
                 : "We're checking your NID and driving license. This usually takes a few minutes \u{2014} you can't go online until it's approved.")
                .font(BrandTypography.body)
                .foregroundStyle(BrandColor.textSecondary)
                .multilineTextAlignment(.center)

            if let error = viewModel.refreshError {
                ErrorBanner(error)
            }
            if viewModel.isAwaitingReview {
                PrimaryButton("Check status", isLoading: viewModel.isRefreshing) {
                    Task { await viewModel.refreshVerification() }
                }
            }
            if viewModel.canResubmit {
                PrimaryButton("Resubmit documents") {
                    viewModel.beginResubmit()
                }
            }
            SecondaryButton("Log Out", action: onLogout)
                .padding(.top, 12)
        }
        .padding()
    }

    /// The documents form again, prefilled with the rejected values, with a Cancel button.
    private var resubmitScreen: some View {
        NavigationStack {
            DriverOnboardingScreen(
                userId: viewModel.driver.id,
                initialVerification: viewModel.verification,
                onSubmitted: viewModel.didResubmit
            )
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { viewModel.cancelResubmit() }
                        .tint(BrandColor.primary)
                }
            }
        }
    }
}

#if DEBUG

/// Driver root for one fake review state, with a throwaway ride-history store.
@MainActor
private func previewDriverRoot(_ viewModel: DriverRootViewModel) -> some View {
    DriverRootScreen(
        driver: viewModel.driver,
        verification: viewModel.verification,
        locationProvider: LocationProvider(),
        rideHistoryStore: RideHistoryStore(defaults: UserDefaults(suiteName: "preview.driverRoot")!),
        onLogout: {},
        viewModel: viewModel
    )
}

#Preview("Verified - tabs") {
    previewDriverRoot(DriverRootViewModel(isPreview: true, status: .verified))
}

#Preview("Pending") {
    previewDriverRoot(DriverRootViewModel(isPreview: true, status: .pending))
}

#Preview("Pending - checking") {
    previewDriverRoot(DriverRootViewModel(isPreview: true, status: .pending, isLoading: true))
}

#Preview("Pending - error") {
    previewDriverRoot(DriverRootViewModel(isPreview: true, status: .pending, isError: true))
}

#Preview("Rejected") {
    previewDriverRoot(DriverRootViewModel(isPreview: true, status: .rejected))
}

#Preview("Rejected - resubmitting") {
    previewDriverRoot(DriverRootViewModel(isPreview: true, status: .rejected, isResubmitting: true))
}

#Preview("Pending - Dark") {
    previewDriverRoot(DriverRootViewModel(isPreview: true, status: .pending))
        .preferredColorScheme(.dark)
}

#endif
