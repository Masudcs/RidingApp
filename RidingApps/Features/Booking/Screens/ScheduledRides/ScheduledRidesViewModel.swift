import Combine
import Foundation
import Observation

/// Backs the scheduled rides sheet. "Start Now" turns a saved ride into a live trip without
/// negotiation, then removes it from the schedule and hands the matched trip to the parent.
@MainActor @Observable
public final class ScheduledRidesViewModel {
    /// Mirror of `ScheduledRidesStore.rides` (soonest first).
    public private(set) var rides: [ScheduledRide] = []
    /// True while a ride is being started; all Start buttons are disabled so a double tap can't book twice.
    public private(set) var isStarting = false
    /// Why the last "Start Now" failed. The ride stays in the list so the rider can retry.
    public private(set) var errorMessage: String?

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    @ObservationIgnored private let store: ScheduledRidesStore
    @ObservationIgnored private let repository: IBookingRepository
    @ObservationIgnored private let womenSafeModeEnabled: Bool
    @ObservationIgnored private let favoriteDriverIds: Set<String>
    @ObservationIgnored private let blockedDriverIds: Set<String>
    @ObservationIgnored private let onStarted: (Trip) -> Void
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    public init(
        store: ScheduledRidesStore,
        womenSafeModeEnabled: Bool = false,
        favoriteDriverIds: Set<String> = [],
        blockedDriverIds: Set<String> = [],
        repository: IBookingRepository = BookingRepository.makeDefault(),
        onStarted: @escaping (Trip) -> Void
    ) {
        self.store = store
        self.womenSafeModeEnabled = womenSafeModeEnabled
        self.favoriteDriverIds = favoriteDriverIds
        self.blockedDriverIds = blockedDriverIds
        self.repository = repository
        self.onStarted = onStarted
        self.rides = store.rides
        store.$rides
            .sink { [weak self] rides in self?.rides = rides }
            .store(in: &cancellables)
    }

    public func routeText(for ride: ScheduledRide) -> String {
        "\(ride.pickup.title) \u{2192} \(ride.dropoff.title)"
    }

    public func dateText(for ride: ScheduledRide) -> String {
        Self.dateFormatter.string(from: ride.scheduledFor)
    }

    public func didDelete(at offsets: IndexSet) {
        // Collect ids first: each removal updates `rides` synchronously and shifts later indices.
        let ids = offsets.compactMap { rides.indices.contains($0) ? rides[$0].id : nil }
        for id in ids {
            store.remove(id: id)
        }
    }

    public func didTapStartNow(_ ride: ScheduledRide) {
        guard !isStarting else { return }
        isStarting = true
        errorMessage = nil
        Task {
            do {
                let matched = try await startScheduledRideNow(ride)
                store.remove(id: ride.id)
                isStarting = false
                onStarted(matched)
            } catch {
                isStarting = false
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Skips negotiation entirely — the fare estimated at scheduling time is what gets agreed,
    /// mirroring how reserved rides work in most real apps.
    private func startScheduledRideNow(_ ride: ScheduledRide) async throws -> Trip {
        await repository.setDriverPreferences(favoriteDriverIds: favoriteDriverIds, blockedDriverIds: blockedDriverIds)
        let trip = try await repository.createNegotiation(
            vehicleType: ride.vehicleType,
            pickup: ride.pickup,
            stops: ride.stops,
            dropoff: ride.dropoff,
            suggestedFare: ride.estimatedFare,
            surge: .none,
            womenSafeModeRequested: womenSafeModeEnabled,
            riderId: ride.riderId,
            riderName: ride.riderName
        )
        do {
            return try await repository.riderAcceptsOffer(tripId: trip.id)
        } catch {
            // Don't leave an open negotiation behind on the backend when the retry would create another.
            try? await repository.cancelNegotiation(tripId: trip.id)
            throw error
        }
    }
}

#if DEBUG

extension ScheduledRidesViewModel {
    /// Preview state backed by a throwaway store and the mock repository. `isLoading` is the
    /// "Start Now tapped" state; `isError` is a failed start.
    convenience init(isPreview: Bool = true, isLoading: Bool = false, isError: Bool = false, isEmptyView: Bool = false, rides: [ScheduledRide]? = nil) {
        self.init(
            store: .mock(rides: isEmptyView ? [] : (rides ?? ScheduledRide.mockList())),
            repository: MockBookingRepository(),
            onStarted: { _ in }
        )
        isStarting = isLoading
        if isError {
            errorMessage = "We couldn't start this ride. Please try again."
        }
    }
}

#endif
