import SwiftUI

/// Drives the rider's trip lifecycle: book -> track -> pay -> rate -> receipt.
///
/// The four optional trip properties below act as the current stage. Normally only one is set at a
/// time, and `RiderHomeScreen` shows the screen for the first one it finds. The stage is saved
/// locally through `TripStageStore` on every change and restored in `init`, so a relaunch mid-trip
/// lands on the same screen. TODO(real API): ask the server for the rider's current trip in
/// `restoreStage()` instead of reading the local copy.
@MainActor
@Observable
final class RiderHomeViewModel {
    /// Trip in progress (driver matched, not yet finished).
    private(set) var activeTrip: Trip?
    /// Trip that just finished and is waiting for payment.
    private(set) var completedTrip: Trip?
    /// Paid trip waiting for the rider to rate the driver.
    private(set) var tripToRate: Trip?
    /// Receipt shown after rating.
    private(set) var lastReceipt: PaymentReceipt?
    // These two are bound to sheets, so the view must be able to set them.
    var showRecordingSheet = false
    var showCancellationSheet = false
    /// Set when the server refused a cancellation; shown as an alert.
    private(set) var cancellationError: String?
    /// Bumped on each failed cancellation so the open sheet re-enables its confirm button.
    private(set) var cancellationFailureCount = 0

    let rider: AppUser
    let bookingRepository: IBookingRepository
    @ObservationIgnored private let loyaltyStore: LoyaltyStore
    @ObservationIgnored private let tripStageStore: TripStageStore
    @ObservationIgnored private let safetyRepository: ISafetyRepository
    @ObservationIgnored private let logger = AppLogger(category: "RiderHome")
    /// Set only by the debug preview initializer; stops saving, cancelling and safety alerts.
    @ObservationIgnored private var isPreview = false

    init(
        rider: AppUser,
        loyaltyStore: LoyaltyStore,
        bookingRepository: IBookingRepository = BookingRepository.makeDefault(),
        safetyRepository: ISafetyRepository = AppEnvironment.current.usesMockServices
            ? MockSafetyRepository.shared
            : SafetyRepository(),
        tripStageStore: TripStageStore = TripStageStore()
    ) {
        self.rider = rider
        self.loyaltyStore = loyaltyStore
        self.bookingRepository = bookingRepository
        self.safetyRepository = safetyRepository
        self.tripStageStore = tripStageStore
        restoreStage()
    }

    /// Puts back the stage saved before the app was closed. Stale or unreadable data is dropped
    /// by the store, so the rider just starts at booking.
    private func restoreStage() {
        guard let snapshot = tripStageStore.load(role: .rider, userId: rider.id) else { return }
        switch snapshot.stage {
        case .active:
            activeTrip = snapshot.trip
        case .awaitingPayment:
            completedTrip = snapshot.trip
        case .awaitingRating:
            tripToRate = snapshot.trip
            lastReceipt = snapshot.receipt
        case .receipt:
            lastReceipt = snapshot.receipt
        }
    }

    /// Saves the current stage, or clears it when the rider is back at booking.
    private func persistStage() {
        guard !isPreview else { return }
        let snapshot: TripStageSnapshot?
        if let trip = completedTrip {
            snapshot = TripStageSnapshot(stage: .awaitingPayment, trip: trip)
        } else if let trip = tripToRate {
            snapshot = TripStageSnapshot(stage: .awaitingRating, trip: trip, receipt: lastReceipt)
        } else if let receipt = lastReceipt {
            snapshot = TripStageSnapshot(stage: .receipt, trip: nil, receipt: receipt)
        } else if let trip = activeTrip {
            snapshot = TripStageSnapshot(stage: .active, trip: trip)
        } else {
            snapshot = nil
        }
        if let snapshot {
            tripStageStore.save(snapshot, role: .rider, userId: rider.id)
        } else {
            tripStageStore.clear(role: .rider, userId: rider.id)
        }
    }

    /// A driver accepted: start tracking. Also used when a scheduled ride starts.
    func didMatchTrip(_ trip: Trip) {
        activeTrip = trip
        persistStage()
    }

    /// The trip ended: move it from active to waiting-for-payment.
    func didCompleteTrip() {
        completedTrip = activeTrip
        activeTrip = nil
        persistStage()
    }

    /// Payment succeeded: record the ride in history, award loyalty points, then ask for a rating.
    /// TODO(real API): history and loyalty points should be recorded by the server.
    func didCompletePayment(for trip: Trip, receipt: PaymentReceipt, recordRide: (RideHistoryEntry) -> Void) {
        recordRide(RideHistoryEntry(
            ownerId: rider.id,
            tripId: trip.id,
            role: .rider,
            counterpartName: trip.driver?.name ?? String(localized: "Driver"),
            vehicleType: trip.vehicleType,
            pickupTitle: trip.pickup.title,
            dropoffTitle: trip.dropoff.title,
            fare: receipt.amount,
            status: .completed
        ))
        loyaltyStore.awardPoints(for: receipt.amount)
        lastReceipt = receipt
        tripToRate = trip
        completedTrip = nil
        persistStage()
    }

    /// Rating done (or skipped): the receipt screen takes over.
    func didFinishRating() {
        tripToRate = nil
        persistStage()
    }

    /// Back to the booking screen.
    func didDismissReceipt() {
        lastReceipt = nil
        persistStage()
    }

    func didTapRecording() {
        showRecordingSheet = true
    }

    func didTapCancelTrip() {
        showCancellationSheet = true
    }

    func didKeepRide() {
        showCancellationSheet = false
    }

    /// Cancels the trip on the backend, and only ends it locally if that worked. If the request
    /// fails, the trip stays active (the server still thinks it is running) and an alert is shown.
    func confirmCancellation(of trip: Trip, reason: CancellationReason, fee: Money) {
        guard !isPreview else { return }
        Task {
            do {
                try await bookingRepository.cancelNegotiation(tripId: trip.id, reason: reason.displayName, fee: fee)
                showCancellationSheet = false
                activeTrip = nil
                persistStage()
            } catch {
                logger.error("Failed to cancel trip: \(error)")
                cancellationError = String(localized: "Please check your connection and try again.")
                cancellationFailureCount += 1
            }
        }
    }

    func dismissCancellationError() {
        cancellationError = nil
    }

    /// The trip left its route or stalled: quietly alert the rider's emergency contacts.
    func didDetectRouteDeviation(_ event: RouteDeviationEvent, tripId: String) {
        guard !isPreview else { return }
        Task {
            do {
                try await safetyRepository.notifyEmergencyContacts(
                    tripId: tripId,
                    location: event.location,
                    reason: Self.deviationReason(for: event)
                )
            } catch {
                logger.error("Failed to notify emergency contacts: \(error)")
            }
        }
    }

    private static func deviationReason(for event: RouteDeviationEvent) -> String {
        switch event.kind {
        case .offRoute(let distanceMeters):
            return String(localized: "Trip has deviated \(Int(distanceMeters))m from the expected route.")
        case .stalled(let seconds):
            return String(localized: "Trip has been stationary for \(Int(seconds))s.")
        }
    }
}

#if DEBUG

extension RiderHomeViewModel {
    /// The trip stage a preview starts in; matches the order the screen checks them.
    enum PreviewStage {
        case booking
        case activeTrip
        case awaitingPayment
        case awaitingRating
        case receipt
    }

    /// Seeds one trip stage with fake data. Uses a throwaway user id, `UserDefaults` suite and mock
    /// repositories, so nothing is restored from or saved to a real user's trip state.
    convenience init(isPreview: Bool = true, stage: PreviewStage = .booking) {
        let defaults = UserDefaults(suiteName: "preview.riderHome")!
        self.init(
            rider: .mockRider(id: "preview-user"),
            loyaltyStore: LoyaltyStore(userId: "preview-user", defaults: defaults),
            safetyRepository: MockSafetyRepository(),
            tripStageStore: TripStageStore(defaults: defaults)
        )
        self.isPreview = isPreview
        switch stage {
        case .booking:
            break
        case .activeTrip:
            activeTrip = .mock(status: .inProgress)
        case .awaitingPayment:
            completedTrip = .mock(status: .completed)
        case .awaitingRating:
            tripToRate = .mock(status: .completed)
            lastReceipt = .mock()
        case .receipt:
            lastReceipt = .mock()
        }
    }
}

#endif
