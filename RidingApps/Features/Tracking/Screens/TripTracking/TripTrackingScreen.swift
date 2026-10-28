import SwiftUI
import MapKit

/// Live map for an active trip: pins, driver position, ETA, share/chat/directions buttons and
/// deviation warnings. Shown by the Ride tab once a driver is matched; the view model reports
/// completion through `onTripCompleted`.
@MainActor
public struct TripTrackingScreen: View {
    @State private var viewModel: TripTrackingViewModel

    private let locationProvider: LocationProvider

    public init(
        trip: Trip,
        currentUserId: String = "",
        currentUserRole: UserRole,
        locationProvider: LocationProvider,
        favoriteDriversStore: FavoriteDriversStore? = nil,
        onTripCompleted: @escaping () -> Void,
        onRouteDeviation: ((RouteDeviationEvent) -> Void)? = nil,
        viewModel: TripTrackingViewModel? = nil
    ) {
        self.locationProvider = locationProvider
        _viewModel = State(wrappedValue: viewModel ?? TripTrackingViewModel(
            trip: trip,
            currentUserId: currentUserId,
            currentUserRole: currentUserRole,
            favoriteDriversStore: favoriteDriversStore,
            onTripCompleted: onTripCompleted,
            onRouteDeviation: onRouteDeviation
        ))
    }

    public var body: some View {
        @Bindable var viewModel = viewModel
        ZStack(alignment: .top) {
            // iOS16-compatible Map API: the trailing-closure `Map { }` / `Marker` builders are iOS17+
            // only, but this package targets iOS 16.
            Map(coordinateRegion: $viewModel.region, annotationItems: viewModel.pins) { pin in
                MapAnnotation(coordinate: pin.coordinate) {
                    TrackingMapPinView(kind: pin.kind)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 12) {
                HStack(alignment: .top) {
                    TripStatusHeader(
                        statusText: viewModel.tripStatusText,
                        vehicleType: viewModel.trip.vehicleType,
                        driverInfo: viewModel.driverInfo,
                        isFavorite: viewModel.isDriverFavorite,
                        isBlocked: viewModel.isDriverBlocked,
                        onToggleFavorite: viewModel.canManageDriver ? { viewModel.didTapToggleFavorite() } : nil,
                        onToggleBlocked: viewModel.canManageDriver ? { viewModel.didTapToggleBlocked() } : nil
                    )

                    ShareLink(item: viewModel.shareSummary) {
                        Image(systemName: "square.and.arrow.up.circle.fill")
                            .font(.title)
                            .foregroundStyle(BrandColor.primary)
                            .background(Circle().fill(.white))
                    }
                    .accessibilityLabel("Share trip tracking details")

                    Button {
                        viewModel.didTapChat()
                    } label: {
                        Image(systemName: "message.circle.fill")
                            .font(.title)
                            .foregroundStyle(BrandColor.primary)
                            .background(Circle().fill(.white))
                    }
                    .accessibilityLabel("Open chat")

                    if viewModel.isDriver {
                        Button {
                            viewModel.didTapDirections()
                        } label: {
                            Image(systemName: "location.north.line.fill")
                                .font(.title)
                                .foregroundStyle(BrandColor.primary)
                                .background(Circle().fill(.white))
                        }
                        .accessibilityLabel("Get directions")
                    }
                }

                ETABanner(etaText: viewModel.etaText)

                if viewModel.isSilentSOSListening {
                    Label("Silent SOS listening", systemImage: "waveform")
                        .font(BrandTypography.caption)
                        .foregroundStyle(BrandColor.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(BrandColor.secondaryBackground)
                        .clipShape(Capsule())
                }

                if let connectionBannerText = viewModel.connectionBannerText {
                    ErrorBanner(connectionBannerText)
                }

                if let deviationBannerText = viewModel.deviationBannerText {
                    Text(deviationBannerText)
                        .font(BrandTypography.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(BrandColor.warning)
                        .clipShape(Capsule())
                        .shadow(radius: 4, y: 2)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut, value: viewModel.deviationBannerText)
            .padding()
        }
        .task {
            viewModel.onAppear(currentLocation: locationProvider.currentLocation)
        }
        .onChange(of: viewModel.isSilentSOSListening) { listening in
            viewModel.silentSOSListeningDidChange(isListening: listening, currentLocation: locationProvider.currentLocation)
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .sheet(isPresented: $viewModel.isShowingChat) {
            NavigationStack {
                ChatScreen(tripId: viewModel.trip.id, currentUserId: viewModel.currentUserId, currentUserRole: viewModel.currentUserRole)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { viewModel.didTapCloseChat() }
                        }
                    }
            }
        }
    }
}

#if DEBUG

@MainActor
private func previewTrackingScreen(_ viewModel: TripTrackingViewModel) -> some View {
    TripTrackingScreen(
        trip: viewModel.trip,
        currentUserId: viewModel.currentUserId,
        currentUserRole: viewModel.currentUserRole,
        locationProvider: LocationProvider(),
        onTripCompleted: {},
        viewModel: viewModel
    )
}

#Preview("Searching for driver") {
    previewTrackingScreen(TripTrackingViewModel(isLoading: true))
}

#Preview("Driver assigned") {
    previewTrackingScreen(TripTrackingViewModel(status: .driverAssigned))
}

#Preview("Driver arriving") {
    previewTrackingScreen(TripTrackingViewModel(status: .driverArriving))
}

#Preview("Trip in progress") {
    previewTrackingScreen(TripTrackingViewModel(status: .inProgress))
}

#Preview("With stops") {
    previewTrackingScreen(TripTrackingViewModel(status: .inProgress, withStops: true))
}

#Preview("Favorite driver") {
    previewTrackingScreen(TripTrackingViewModel(isFavoriteDriver: true))
}

#Preview("Driver view") {
    previewTrackingScreen(TripTrackingViewModel(role: .driver))
}

#Preview("Connection problem") {
    previewTrackingScreen(TripTrackingViewModel(isError: true))
}

#Preview("Route deviation warning") {
    previewTrackingScreen(TripTrackingViewModel(status: .inProgress, hasDeviationWarning: true))
}

#Preview("Silent SOS listening") {
    previewTrackingScreen(TripTrackingViewModel(isSilentSOSActive: true))
}

#endif
