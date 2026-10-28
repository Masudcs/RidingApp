import SwiftUI

/// Drives the driver's Home tab: online toggle, incoming requests, and the trip lifecycle
/// (accepted -> completed -> rating, or cancelled). Only one of `activeTrip` / `tripPendingRating`
/// is set at a time.
///
/// The trip stage is saved through `TripStageStore` and restored in `init`, so a relaunch mid-trip
/// keeps the driver on the trip or the rating step. `isOnline` is deliberately not restored: the
/// driver always comes back offline and must go online again, so they never receive requests
/// they did not expect after a relaunch. TODO(real API): ask the server for the driver's current
/// trip in `restoreStage()` instead of reading the local copy.
@MainActor
@Observable
final class DriverHomeViewModel {
    /// Toggled by the driver; the screen calls `refresh()` whenever it changes.
    var isOnline = false
    /// Open ride requests shown as cards. Emptied when the driver goes offline.
    private(set) var incomingRequests: [Trip] = []
    private(set) var isLoading = false
    /// Shown as a banner on the idle screen only; cleared on the next successful action.
    var errorMessage: String?
    /// Trip the driver accepted and is currently running.
    private(set) var activeTrip: Trip?
    /// Completed trip waiting for the driver to rate the rider.
    private(set) var tripPendingRating: Trip?

    var showRecordingSheet = false
    var showCancelSheet = false
    /// Trips with an accept/counter/decline call in flight, so a double tap can't send it twice.
    @ObservationIgnored private var respondingTripIds: Set<String> = []

    @ObservationIgnored private let service: IBookingRepository
    @ObservationIgnored private let safetyRepository: ISafetyRepository
    @ObservationIgnored private let logger = AppLogger(category: "DriverHome")
    @ObservationIgnored private let tripStageStore: TripStageStore
    /// Key for the saved stage. When nil (previews, tests that don't care) nothing is saved.
    @ObservationIgnored private let driverId: String?
    /// Set only by the debug preview initializer; stops loading, responding, saving and safety alerts.
    @ObservationIgnored private var isPreview = false

    init(
        driverId: String? = nil,
        service: IBookingRepository = BookingRepository.makeDefault(),
        safetyRepository: ISafetyRepository = AppEnvironment.current.usesMockServices
            ? MockSafetyRepository.shared
            : SafetyRepository(),
        tripStageStore: TripStageStore = TripStageStore()
    ) {
        self.driverId = driverId
        self.service = service
        self.safetyRepository = safetyRepository
        self.tripStageStore = tripStageStore
        restoreStage()
    }

    /// Puts back the active trip or the rating step saved before the app was closed. Stale or
    /// unreadable data is dropped by the store.
    private func restoreStage() {
        guard let driverId, let snapshot = tripStageStore.load(role: .driver, userId: driverId) else { return }
        switch snapshot.stage {
        case .active:
            activeTrip = snapshot.trip
        case .awaitingRating:
            tripPendingRating = snapshot.trip
        case .awaitingPayment, .receipt:
            // Rider-only stages; never saved for a driver.
            tripStageStore.clear(role: .driver, userId: driverId)
        }
    }

    /// Saves the current stage, or clears it when the driver is back at the idle screen.
    private func persistStage() {
        guard !isPreview else { return }
        guard let driverId else { return }
        if let trip = activeTrip {
            tripStageStore.save(TripStageSnapshot(stage: .active, trip: trip), role: .driver, userId: driverId)
        } else if let trip = tripPendingRating {
            tripStageStore.save(TripStageSnapshot(stage: .awaitingRating, trip: trip), role: .driver, userId: driverId)
        } else {
            tripStageStore.clear(role: .driver, userId: driverId)
        }
    }

    /// Label next to the online toggle.
    var statusTitle: String {
        isOnline ? String(localized: "You're online") : String(localized: "You're offline")
    }

    func didTapRecording() {
        showRecordingSheet = true
    }

    func didTapCancelTrip() {
        showCancelSheet = true
    }

    func didKeepTrip() {
        showCancelSheet = false
    }

    func didConfirmCancel(reason: DriverCancellationReason) {
        cancelActiveTrip(reason: reason)
        showCancelSheet = false
    }

    /// Tracking calls this when the trip goes off-route or stalls; emergency contacts are notified
    /// in the background and a failure is only logged.
    func didDetectRouteDeviation(_ event: RouteDeviationEvent, tripId: String) {
        guard !isPreview else { return }
        Task {
            do {
                try await safetyRepository.notifyEmergencyContacts(
                    tripId: tripId,
                    location: event.location,
                    reason: "Route deviation or stall detected during trip."
                )
            } catch {
                logger.error("Failed to notify emergency contacts: \(error)")
            }
        }
    }

    /// Builds the history row for a finished trip. Called once rating is done, not at completion.
    func rideHistoryEntry(for trip: Trip, driverId: String) -> RideHistoryEntry {
        RideHistoryEntry(
            ownerId: driverId,
            tripId: trip.id,
            role: .driver,
            counterpartName: trip.riderName.isEmpty ? String(localized: "Rider") : trip.riderName,
            vehicleType: trip.vehicleType,
            pickupTitle: trip.pickup.title,
            dropoffTitle: trip.dropoff.title,
            fare: trip.agreedFare ?? trip.suggestedFare,
            status: .completed
        )
    }

    /// Loads open requests while online. Going offline clears the list so stale requests can't be
    /// accepted later.
    func refresh() async {
        guard !isPreview else { return }
        guard isOnline else {
            incomingRequests = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            incomingRequests = try await service.incomingRequestsForDriver()
            errorMessage = nil
        } catch {
            logger.error("Failed to refresh incoming requests: \(error)")
            errorMessage = String(localized: "Couldn't load nearby requests. Pull to retry.")
        }
    }

    /// Accept, counter or decline a request. Accepting starts the active trip. On failure the
    /// request is kept in the list and an error is shown; the server may have withdrawn it.
    func respond(to trip: Trip, response: OfferResponse) {
        guard !isPreview else { return }
        guard respondingTripIds.insert(trip.id).inserted else { return }
        Task {
            defer { respondingTripIds.remove(trip.id) }
            do {
                let updated = try await service.respondToOffer(tripId: trip.id, response: response)
                errorMessage = nil
                incomingRequests.removeAll { $0.id == trip.id }
                if case .accept = response {
                    activeTrip = updated
                    persistStage()
                }
            } catch {
                logger.error("Failed to respond to offer: \(error)")
                errorMessage = String(localized: "That request is no longer available.")
            }
        }
    }

    /// Called by tracking when the trip ends; moves the trip into the rating step.
    func handleTripCompleted() {
        tripPendingRating = activeTrip
        activeTrip = nil
        persistStage()
    }

    /// Cancels on the server first and only clears `activeTrip` once that succeeds, so a failed
    /// call leaves the driver on the trip. Driver cancellations carry no fee.
    func cancelActiveTrip(reason: DriverCancellationReason) {
        guard !isPreview else { return }
        guard let tripId = activeTrip?.id else { return }
        Task {
            do {
                try await service.cancelNegotiation(tripId: tripId, reason: reason.displayName, fee: .bdt(0))
                activeTrip = nil
                persistStage()
            } catch {
                logger.error("Failed to cancel active trip: \(error)")
                errorMessage = String(localized: "Couldn't cancel this trip. Please try again.")
            }
        }
    }

    /// Called when the rating screen is done (submitted or skipped); returns to the idle screen.
    func finishRatingRider() {
        tripPendingRating = nil
        persistStage()
    }
}

#if DEBUG

extension DriverHomeViewModel {
    /// The state a preview starts in.
    enum PreviewStage {
        case offline
        /// Online with no requests yet (the "Looking for ride requests" spinner).
        case searching
        case incomingRequests
        case error
        case activeTrip
        case awaitingRating
    }

    /// Seeds one state with fake data. Uses a throwaway driver id, `UserDefaults` suite and mock
    /// repositories, so nothing is restored from or saved to a real driver's trip state.
    convenience init(isPreview: Bool = true, stage: PreviewStage) {
        let defaults = UserDefaults(suiteName: "preview.driverHome")!
        self.init(
            driverId: "preview-user",
            safetyRepository: MockSafetyRepository(),
            tripStageStore: TripStageStore(defaults: defaults)
        )
        self.isPreview = isPreview
        switch stage {
        case .offline:
            break
        case .searching:
            isOnline = true
        case .incomingRequests:
            isOnline = true
            incomingRequests = [.mock(status: .negotiating)]
        case .error:
            isOnline = true
            errorMessage = String(localized: "Couldn't load nearby requests. Pull to retry.")
        case .activeTrip:
            activeTrip = .mock(status: .inProgress)
        case .awaitingRating:
            tripPendingRating = .mock(status: .completed)
        }
    }
}

#endif
