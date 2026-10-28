import SwiftUI

/// The "Ride" tab. It shows ONE screen depending on where the rider is in the trip lifecycle:
///
///     book -> track the trip -> pay -> rate the driver -> receipt -> (book again)
///
/// The checks below run top to bottom and the first match wins, so later stages take priority:
/// payment, then rating, then the active trip, then the receipt, then the booking form.
/// `RiderHomeViewModel` owns the state and moves between stages.
struct RiderHomeScreen: View {
    @ObservedObject var savedPlacesStore: SavedPlacesStore
    @ObservedObject var scheduledRidesStore: ScheduledRidesStore
    @ObservedObject var favoriteDriversStore: FavoriteDriversStore

    @State private var viewModel: RiderHomeViewModel
    let locationProvider: LocationProvider
    let rideHistoryStore: RideHistoryStore

    init(
        rider: AppUser,
        savedPlacesStore: SavedPlacesStore,
        scheduledRidesStore: ScheduledRidesStore,
        favoriteDriversStore: FavoriteDriversStore,
        loyaltyStore: LoyaltyStore,
        locationProvider: LocationProvider,
        rideHistoryStore: RideHistoryStore,
        viewModel: RiderHomeViewModel? = nil
    ) {
        self.locationProvider = locationProvider
        self.rideHistoryStore = rideHistoryStore
        self.savedPlacesStore = savedPlacesStore
        self.scheduledRidesStore = scheduledRidesStore
        self.favoriteDriversStore = favoriteDriversStore
        _viewModel = State(wrappedValue: viewModel ?? RiderHomeViewModel(rider: rider, loyaltyStore: loyaltyStore))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        Group {
            if let trip = viewModel.completedTrip {
                // Trip just ended: collect payment. The ride is saved to history afterwards.
                PaymentCheckoutScreen(trip: trip) { receipt in
                    viewModel.didCompletePayment(for: trip, receipt: receipt, recordRide: rideHistoryStore.record)
                }
            } else if let trip = viewModel.tripToRate, let driver = trip.driver {
                // Paid: ask the rider to rate the driver.
                RateTripScreen(
                    tripId: trip.id,
                    raterId: viewModel.rider.id,
                    raterRole: .rider,
                    ratedUserId: driver.driverId,
                    ratedUserName: driver.name,
                    onDone: viewModel.didFinishRating
                )
            } else if let trip = viewModel.activeTrip {
                // Trip in progress: live tracking with floating buttons for recording, cancel and SOS.
                ZStack(alignment: .bottomTrailing) {
                    TripTrackingScreen(
                        trip: trip,
                        currentUserId: viewModel.rider.id,
                        currentUserRole: .rider,
                        locationProvider: locationProvider,
                        favoriteDriversStore: favoriteDriversStore,
                        onTripCompleted: viewModel.didCompleteTrip,
                        onRouteDeviation: { event in
                            viewModel.didDetectRouteDeviation(event, tripId: trip.id)
                        }
                    )
                    VStack(spacing: 12) {
                        Button(action: viewModel.didTapRecording) {
                            Image(systemName: "mic.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(BrandColor.primary)
                                .background(Circle().fill(.white))
                        }
                        .accessibilityLabel("Open trip recording controls")
                        Button(action: viewModel.didTapCancelTrip) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(BrandColor.danger)
                                .background(Circle().fill(.white))
                        }
                        .accessibilityLabel("Cancel trip")
                        SOSScreen(
                            tripId: trip.id,
                            currentUserRole: .rider,
                            currentLocation: locationProvider.currentLocation ?? trip.pickup.point
                        )
                    }
                    .padding()
                }
                .task {
                    #if DEBUG
                    // Previews must not start CoreLocation.
                    guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
                    #endif
                    locationProvider.startUpdating()
                }
                .sheet(isPresented: $viewModel.showRecordingSheet) {
                    TripRecordingScreen(tripId: trip.id)
                }
                .sheet(isPresented: $viewModel.showCancellationSheet) {
                    CancellationScreen(trip: trip, confirmationFailureCount: viewModel.cancellationFailureCount, onConfirm: { reason, fee in
                        viewModel.confirmCancellation(of: trip, reason: reason, fee: fee)
                    }, onKeepRide: viewModel.didKeepRide)
                        // Shown on top of the sheet if the server refuses the cancellation, so the
                        // rider can try again or keep the ride instead of silently losing the trip.
                        .alert(
                            "Couldn't cancel the trip",
                            isPresented: Binding(
                                get: { viewModel.cancellationError != nil },
                                set: { if !$0 { viewModel.dismissCancellationError() } }
                            )
                        ) {
                            Button("OK", role: .cancel) {}
                        } message: {
                            Text(viewModel.cancellationError ?? "")
                        }
                }
            } else if let receipt = viewModel.lastReceipt {
                // After rating: show the receipt until the rider dismisses it.
                TripReceiptView(receipt: receipt, onDismiss: viewModel.didDismissReceipt)
            } else {
                // Default: nothing in progress, so show the booking flow.
                BookingFlowScreen(
                    rider: viewModel.rider,
                    repository: viewModel.bookingRepository,
                    savedPlaces: savedPlacesStore.places,
                    scheduledRidesStore: scheduledRidesStore,
                    favoriteDriversStore: favoriteDriversStore,
                    onTripMatched: viewModel.didMatchTrip,
                    onScheduledRideStarted: viewModel.didMatchTrip,
                    onCancelled: {}
                )
            }
        }
    }
}

/// Final screen of a trip: confirmation, amount paid and payment method, with a button to book again.
private struct TripReceiptView: View {
    let receipt: PaymentReceipt
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(BrandColor.success)
            Text("Trip complete")
                .font(BrandTypography.title)
            Text(receipt.amount.formatted)
                .font(BrandTypography.largeTitle)
            Text("Paid via \(receipt.method.displayName)")
                .font(BrandTypography.body)
                .foregroundStyle(BrandColor.textSecondary)
            PrimaryButton("Book Another Ride") {
                onDismiss()
            }
            .padding(.top, 24)
        }
        .padding()
    }
}

#if DEBUG

/// The Ride tab in one trip stage, with every store kept in a private `UserDefaults` suite.
@MainActor
private func previewRiderHome(_ stage: RiderHomeViewModel.PreviewStage) -> some View {
    let defaults = UserDefaults(suiteName: "preview.riderHome")!
    return RiderHomeScreen(
        rider: .mockRider(id: "preview-user"),
        savedPlacesStore: SavedPlacesStore(userId: "preview-user", defaults: defaults),
        scheduledRidesStore: ScheduledRidesStore(userId: "preview-user", defaults: defaults),
        favoriteDriversStore: FavoriteDriversStore(userId: "preview-user", defaults: defaults),
        loyaltyStore: LoyaltyStore(userId: "preview-user", defaults: defaults),
        locationProvider: LocationProvider(),
        rideHistoryStore: RideHistoryStore(defaults: defaults),
        viewModel: RiderHomeViewModel(stage: stage)
    )
}

#Preview("Booking") {
    previewRiderHome(.booking)
}

#Preview("Active trip") {
    previewRiderHome(.activeTrip)
}

#Preview("Awaiting payment") {
    previewRiderHome(.awaitingPayment)
}

#Preview("Awaiting rating") {
    previewRiderHome(.awaitingRating)
}

#Preview("Receipt") {
    previewRiderHome(.receipt)
}

#Preview("Receipt - Dark") {
    previewRiderHome(.receipt)
        .preferredColorScheme(.dark)
}

#Preview("Trip receipt view") {
    TripReceiptView(receipt: .mock(), onDismiss: {})
}

#endif
