import SwiftUI

/// Driver's Home tab. Switches between three states driven by the view model: an active trip
/// (tracking + recording/cancel/SOS controls), rating the rider after a completed trip, and the
/// online/offline toggle with incoming ride requests. The ride is saved to history only after
/// the rating screen finishes.
struct DriverHomeScreen: View {
    let driver: AppUser
    @State private var viewModel: DriverHomeViewModel
    let locationProvider: LocationProvider
    let rideHistoryStore: RideHistoryStore

    init(driver: AppUser, locationProvider: LocationProvider, rideHistoryStore: RideHistoryStore, viewModel: DriverHomeViewModel? = nil) {
        self.driver = driver
        self.locationProvider = locationProvider
        self.rideHistoryStore = rideHistoryStore
        _viewModel = State(wrappedValue: viewModel ?? DriverHomeViewModel(driverId: driver.id))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        if let trip = viewModel.activeTrip {
            ZStack(alignment: .bottomTrailing) {
                TripTrackingScreen(
                    trip: trip,
                    currentUserId: driver.id,
                    currentUserRole: .driver,
                    locationProvider: locationProvider,
                    onTripCompleted: viewModel.handleTripCompleted,
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
                        currentUserRole: .driver,
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
            .sheet(isPresented: $viewModel.showCancelSheet) {
                DriverCancelTripScreen(
                    onConfirm: viewModel.didConfirmCancel,
                    onKeepTrip: viewModel.didKeepTrip
                )
            }
        } else if let trip = viewModel.tripPendingRating {
            RateTripScreen(
                tripId: trip.id,
                raterId: driver.id,
                raterRole: .driver,
                ratedUserId: trip.riderId,
                ratedUserName: trip.riderName.isEmpty ? String(localized: "your rider") : trip.riderName,
                onDone: {
                    rideHistoryStore.record(viewModel.rideHistoryEntry(for: trip, driverId: driver.id))
                    viewModel.finishRatingRider()
                }
            )
        } else {
            NavigationStack {
                VStack(spacing: 12) {
                    Toggle(isOn: $viewModel.isOnline) {
                        Text(viewModel.statusTitle)
                            .font(BrandTypography.headline)
                    }
                    .tint(BrandColor.primary)
                    .padding()
                    .background(BrandColor.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal)

                    if let errorMessage = viewModel.errorMessage {
                        ErrorBanner(errorMessage)
                            .padding(.horizontal)
                    }

                    if viewModel.isOnline {
                        if viewModel.incomingRequests.isEmpty {
                            Spacer()
                            ProgressView()
                            Text("Looking for ride requests nearby\u{2026}")
                                .font(BrandTypography.body)
                                .foregroundStyle(BrandColor.textSecondary)
                            Spacer()
                        } else {
                            ScrollView {
                                VStack(spacing: 12) {
                                    ForEach(viewModel.incomingRequests) { trip in
                                        DriverIncomingRequestCard(
                                            trip: trip,
                                            onAccept: { viewModel.respond(to: trip, response: .accept) },
                                            onCounter: { amount in viewModel.respond(to: trip, response: .counter(amount)) },
                                            onDecline: { viewModel.respond(to: trip, response: .decline) }
                                        )
                                    }
                                }
                                .padding()
                            }
                        }
                    } else {
                        Spacer()
                        Text("Go online to start receiving ride requests.")
                            .font(BrandTypography.body)
                            .foregroundStyle(BrandColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding()
                        Spacer()
                    }
                }
                .navigationTitle("Driver")
                .task(id: viewModel.isOnline) {
                    await viewModel.refresh()
                }
            }
        }
    }
}

#if DEBUG

/// The Driver tab in one state, with a throwaway ride-history store.
@MainActor
private func previewDriverHome(_ stage: DriverHomeViewModel.PreviewStage) -> some View {
    DriverHomeScreen(
        driver: .mockDriver(id: "preview-user"),
        locationProvider: LocationProvider(),
        rideHistoryStore: RideHistoryStore(defaults: UserDefaults(suiteName: "preview.driverHome")!),
        viewModel: DriverHomeViewModel(stage: stage)
    )
}

#Preview("Offline") {
    previewDriverHome(.offline)
}

#Preview("Online - searching") {
    previewDriverHome(.searching)
}

#Preview("Incoming request") {
    previewDriverHome(.incomingRequests)
}

#Preview("Error") {
    previewDriverHome(.error)
}

#Preview("Active trip") {
    previewDriverHome(.activeTrip)
}

#Preview("Awaiting rating") {
    previewDriverHome(.awaitingRating)
}

#Preview("Incoming request - Dark") {
    previewDriverHome(.incomingRequests)
        .preferredColorScheme(.dark)
}

#endif
