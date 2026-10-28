import SwiftUI

/// Root of the rider's Ride tab: a `NavigationStack` that walks vehicle -> location -> fare
/// negotiation, plus a toolbar button that opens scheduled rides in a sheet. Navigation state is
/// in `BookingFlowViewModel`. Once a driver is matched (or a ride is cancelled / started from the
/// schedule list) the parent is told through the `on...` closures and takes over.
@MainActor
public struct BookingFlowScreen: View {
    private let rider: AppUser
    private let savedPlaces: [SavedPlace]
    private let repository: IBookingRepository
    private let onTripMatched: (Trip) -> Void
    private let onCancelled: () -> Void
    private let onScheduledRideStarted: (Trip) -> Void

    @ObservedObject private var scheduledRidesStore: ScheduledRidesStore
    /// Favorite/blocked drivers, passed on so matching can honor them.
    @ObservedObject private var favoriteDriversStore: FavoriteDriversStore
    @State private var viewModel: BookingFlowViewModel

    public init(
        rider: AppUser,
        repository: IBookingRepository = BookingRepository.makeDefault(),
        savedPlaces: [SavedPlace] = [],
        scheduledRidesStore: ScheduledRidesStore,
        favoriteDriversStore: FavoriteDriversStore? = nil,
        onTripMatched: @escaping (Trip) -> Void,
        onScheduledRideStarted: @escaping (Trip) -> Void = { _ in },
        onCancelled: @escaping () -> Void
    ) {
        self.rider = rider
        self.repository = repository
        self.savedPlaces = savedPlaces
        self.scheduledRidesStore = scheduledRidesStore
        self.favoriteDriversStore = favoriteDriversStore ?? FavoriteDriversStore()
        self.onTripMatched = onTripMatched
        self.onCancelled = onCancelled
        self.onScheduledRideStarted = onScheduledRideStarted
        _viewModel = State(wrappedValue: BookingFlowViewModel())
    }

    public var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack(path: $viewModel.path) {
            VehiclePickerScreen { vehicleType in
                viewModel.didContinueFromVehicle(vehicleType)
            }
            .navigationDestination(for: BookingFlowViewModel.Step.self) { step in
                switch step {
                case .location(let vehicleType):
                    LocationPickerScreen(
                        vehicleType: vehicleType,
                        savedPlaces: savedPlaces,
                        repository: repository
                    ) { draft in
                        viewModel.didContinueFromLocation(draft)
                    }
                case .negotiation(let draft):
                    FareNegotiationScreen(
                        rider: rider,
                        draft: draft,
                        scheduledRidesStore: scheduledRidesStore,
                        favoriteDriverIds: favoriteDriversStore.favoriteIds,
                        blockedDriverIds: favoriteDriversStore.blockedIds,
                        repository: repository,
                        onTripMatched: onTripMatched,
                        onScheduledRideConfirmed: { viewModel.didConfirmScheduledRide() },
                        onCancelled: onCancelled
                    )
                }
            }
            .navigationTitle("Book a ride")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.didTapScheduledRides()
                    } label: {
                        Label("Scheduled", systemImage: "clock")
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showScheduledRides) {
            ScheduledRidesScreen(
                store: scheduledRidesStore,
                womenSafeModeEnabled: rider.womenSafeModeEnabled,
                favoriteDriverIds: favoriteDriversStore.favoriteIds,
                blockedDriverIds: favoriteDriversStore.blockedIds,
                repository: repository
            ) { matched in
                viewModel.didStartScheduledRide()
                onScheduledRideStarted(matched)
            }
        }
    }
}

#if DEBUG

extension BookingFlowScreen {
    /// Preview-only: mock repository and throwaway stores, with a ready-made navigation state.
    init(previewViewModel: BookingFlowViewModel, savedPlaces: [SavedPlace] = SavedPlace.mockList()) {
        self.rider = .mockRider()
        self.savedPlaces = savedPlaces
        self.repository = MockBookingRepository()
        self.onTripMatched = { _ in }
        self.onCancelled = {}
        self.onScheduledRideStarted = { _ in }
        self.scheduledRidesStore = ScheduledRidesStore.mock()
        self.favoriteDriversStore = FavoriteDriversStore.mock()
        _viewModel = State(wrappedValue: previewViewModel)
    }
}

#Preview("Vehicle step") {
    BookingFlowScreen(previewViewModel: BookingFlowViewModel(path: []))
}

#Preview("Location step") {
    BookingFlowScreen(previewViewModel: BookingFlowViewModel(path: [.location(.car)]))
}

#Preview("Fare step") {
    BookingFlowScreen(previewViewModel: BookingFlowViewModel(path: [.negotiation(.mock(withStops: true))]))
}

#Preview("Scheduled rides sheet") {
    BookingFlowScreen(previewViewModel: BookingFlowViewModel(path: [], showScheduledRides: true))
}

#endif
