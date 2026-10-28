import Foundation
import Observation

/// Third step: shows the estimated fare, then either
///  - requests the ride and runs the offer / counter-offer chat with the driver until one is
///    matched (`onTripMatched`), or
///  - saves the ride for later when "Schedule for later" is on (`onScheduledRideConfirmed`).
/// The rider can cancel once a trip exists (`onCancelled`).
@MainActor @Observable
public final class FareNegotiationViewModel {
    /// From `estimateFare`; nil until it loads (or if it failed). Requesting a ride needs it.
    public private(set) var suggestedFare: Money?
    public private(set) var surgeContext: SurgeContext = .none
    /// Nil until the ride is requested; the screen switches to the offer chat once it is set.
    public private(set) var trip: Trip?
    /// Raw text of the offer field; parsed and validated by `Money.bdt(parsing:)` on propose.
    public var myOfferAmount: String = ""
    /// True while any request runs; buttons use it to block double taps.
    public private(set) var isLoading: Bool = false
    public private(set) var errorMessage: String?
    /// Non-nil when "Schedule for later" is on.
    public private(set) var scheduledFor: Date?
    public var showSurgeSheet = false
    public var showCancellationSheet = false

    @ObservationIgnored private let draft: RideRequestDraft
    @ObservationIgnored private let rider: AppUser
    @ObservationIgnored private let repository: IBookingRepository
    @ObservationIgnored private let scheduledRidesStore: ScheduledRidesStore
    @ObservationIgnored private let favoriteDriverIds: Set<String>
    @ObservationIgnored private let blockedDriverIds: Set<String>
    @ObservationIgnored private let onTripMatched: (Trip) -> Void
    @ObservationIgnored private let onScheduledRideConfirmed: () -> Void
    @ObservationIgnored private let onCancelled: () -> Void
    @ObservationIgnored private var hasLoaded = false
    @ObservationIgnored private var isCancelling = false
    @ObservationIgnored private var hasConfirmedSchedule = false
    /// Set only by the preview initializer: keeps the real loads from replacing the fake data.
    @ObservationIgnored private var isPreview = false

    public init(
        rider: AppUser,
        draft: RideRequestDraft,
        scheduledRidesStore: ScheduledRidesStore,
        favoriteDriverIds: Set<String> = [],
        blockedDriverIds: Set<String> = [],
        repository: IBookingRepository = BookingRepository.makeDefault(),
        onTripMatched: @escaping (Trip) -> Void,
        onScheduledRideConfirmed: @escaping () -> Void,
        onCancelled: @escaping () -> Void
    ) {
        self.rider = rider
        self.draft = draft
        self.scheduledRidesStore = scheduledRidesStore
        self.favoriteDriverIds = favoriteDriverIds
        self.blockedDriverIds = blockedDriverIds
        self.repository = repository
        self.onTripMatched = onTripMatched
        self.onScheduledRideConfirmed = onScheduledRideConfirmed
        self.onCancelled = onCancelled
    }

    // MARK: - Presentation

    public var suggestedFareText: String {
        suggestedFare?.formatted ?? "--"
    }

    public var insuranceText: String {
        String(localized: "Includes \((trip?.insurancePremium ?? defaultInsurancePremium).formatted) micro-insurance")
    }

    public var stopsText: String? {
        guard !draft.stops.isEmpty else { return nil }
        let count = draft.stops.count
        let titles = draft.stops.map(\.title).joined(separator: ", ")
        return count == 1 ? String(localized: "1 stop: \(titles)") : String(localized: "\(count) stops: \(titles)")
    }

    public var isSurging: Bool {
        surgeContext.multiplier > 1.0
    }

    private var surgeMultiplierText: String {
        String(format: "%.1f", surgeContext.multiplier)
    }

    public var surgeButtonTitle: String {
        String(localized: "\(surgeMultiplierText)x surge — why?")
    }

    public var surgeSheetTitle: String {
        String(localized: "Price is \(surgeMultiplierText)x higher right now")
    }

    public var surgeReasons: [String] {
        surgeContext.reasons
    }

    public var offers: [FareOffer] {
        trip?.offers ?? []
    }

    public var hasTrip: Bool {
        trip != nil
    }

    /// Only for Women Safe Mode trips: "matching" until a driver is assigned, then a fallback
    /// notice if that driver is not female.
    public var womenSafeNotice: WomenSafeNotice? {
        guard trip?.womenSafeModeRequested == true else { return nil }
        if let driver = trip?.driver {
            return driver.gender != .female ? .fallbackDriver : nil
        }
        return .matching
    }

    /// Non-nil only when the driver made the latest offer; that is the only time the rider can accept.
    public var acceptButtonTitle: String? {
        guard let latestOffer = trip?.offers.last, latestOffer.author == .driver else { return nil }
        return String(localized: "Accept \(latestOffer.amount.formatted)")
    }

    public var canPropose: Bool {
        !myOfferAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    // MARK: - Actions

    /// First appearance only: sync favorite/blocked drivers, then load the fare estimate. They run
    /// in order so preferences are in place before any ride can be requested.
    public func didAppear() {
        guard !isPreview else { return }
        guard !hasLoaded else { return }
        hasLoaded = true
        Task {
            await repository.setDriverPreferences(favoriteDriverIds: favoriteDriverIds, blockedDriverIds: blockedDriverIds)
            await loadEstimate()
        }
    }

    /// Also used to retry when the first estimate failed and the rider taps "Request ride".
    private func loadEstimate() async {
        await run {
            let estimate = try await self.repository.estimateFare(
                vehicleType: self.draft.vehicleType,
                pickup: self.draft.pickup,
                stops: self.draft.stops,
                dropoff: self.draft.dropoff
            )
            self.suggestedFare = estimate.suggestedFare
            self.surgeContext = estimate.surge
        }
    }

    public func didTapSurgeInfo() {
        showSurgeSheet = true
    }

    public func didToggleSchedule(_ isOn: Bool) {
        scheduledFor = isOn ? Date().addingTimeInterval(3600) : nil
    }

    public func didChangeScheduledDate(_ date: Date) {
        scheduledFor = date
    }

    /// Creates the negotiation. Ignored while another request runs or a trip already exists, so a
    /// double tap can't open two trips. If the estimate never loaded, this retries it instead.
    public func didTapRequestRide() {
        guard !isLoading, trip == nil else { return }
        guard suggestedFare != nil else {
            Task { await loadEstimate() }
            return
        }
        Task {
            await run {
                guard let suggestedFare = self.suggestedFare, self.trip == nil else { return }
                let trip = try await self.repository.createNegotiation(
                    vehicleType: self.draft.vehicleType,
                    pickup: self.draft.pickup,
                    stops: self.draft.stops,
                    dropoff: self.draft.dropoff,
                    suggestedFare: suggestedFare,
                    surge: self.surgeContext,
                    womenSafeModeRequested: self.rider.womenSafeModeEnabled,
                    riderId: self.rider.id,
                    riderName: self.rider.fullName
                )
                self.trip = trip
                Analytics.track("ride_requested", ["vehicleType": self.draft.vehicleType.rawValue])
                self.handle(trip)
            }
        }
    }

    /// Saves the ride locally; no request is made now. The date must still be in the future
    /// (the picker's lower bound is only set when it is drawn).
    public func didTapConfirmScheduledRide() {
        guard !hasConfirmedSchedule, let scheduledFor, let suggestedFare else { return }
        guard scheduledFor > Date() else {
            errorMessage = String(localized: "Pick a pickup time in the future.")
            return
        }
        hasConfirmedSchedule = true
        errorMessage = nil
        let ride = ScheduledRide(
            riderId: rider.id,
            riderName: rider.fullName,
            vehicleType: draft.vehicleType,
            pickup: draft.pickup,
            stops: draft.stops,
            dropoff: draft.dropoff,
            estimatedFare: suggestedFare,
            scheduledFor: scheduledFor
        )
        scheduledRidesStore.add(ride)
        onScheduledRideConfirmed()
    }

    /// Sends the rider's counter-offer. Invalid or non-positive text shows an error instead.
    public func didTapPropose() {
        guard !isLoading else { return }
        guard let tripId = trip?.id, let amount = Money.bdt(parsing: myOfferAmount) else {
            errorMessage = String(localized: "Enter a valid fare amount")
            return
        }
        Task {
            await run {
                let updated = try await self.repository.submitRiderOffer(tripId: tripId, amount: amount)
                self.trip = updated
                self.myOfferAmount = ""
                self.handle(updated)
            }
        }
    }

    /// Accepts the driver's latest offer; the trip then comes back matched.
    public func didTapAcceptOffer() {
        guard !isLoading, acceptButtonTitle != nil, let tripId = trip?.id else { return }
        Task {
            await run {
                let updated = try await self.repository.riderAcceptsOffer(tripId: tripId)
                self.trip = updated
                self.handle(updated)
            }
        }
    }

    public func didTapCancelRide() {
        showCancellationSheet = true
    }

    public func didKeepRide() {
        showCancellationSheet = false
    }

    /// Closes the sheet and cancels on the backend. `onCancelled` fires only after that succeeds;
    /// on failure the rider stays on this screen with the error, since the trip is still open.
    public func didConfirmCancellation(reason: CancellationReason, fee: Money) {
        showCancellationSheet = false
        guard let tripId = trip?.id else {
            onCancelled()
            return
        }
        guard !isCancelling else { return }
        isCancelling = true
        Task {
            let succeeded = await run {
                try await self.repository.cancelNegotiation(tripId: tripId, reason: reason.displayName, fee: fee)
                Analytics.track("ride_cancelled", ["reason": reason.displayName])
                self.trip = nil
            }
            isCancelling = false
            if succeeded { onCancelled() }
        }
    }

    /// Called with every trip update; a `.driverAssigned` trip ends this step.
    private func handle(_ trip: Trip) {
        if trip.status == .driverAssigned {
            if let driver = trip.driver {
                LocalNotifications.notify(
                    title: String(localized: "Driver matched!"),
                    body: String(localized: "\(driver.name) is on the way in a \(driver.vehicleType.displayName).")
                )
            }
            Analytics.track("ride_matched", ["vehicleType": trip.vehicleType.rawValue])
            onTripMatched(trip)
        }
    }

    /// Runs one request with the loading flag and error message handled. Returns false on failure.
    @discardableResult
    private func run(_ operation: @escaping () async throws -> Void) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await operation()
            return true
        } catch {
            errorMessage = (error as? BookingError) != nil ? String(localized: "Trip could not be found. Please try again.") : error.localizedDescription
            return false
        }
    }
}

#if DEBUG

extension FareNegotiationViewModel {
    /// Preview state with a fixed estimate (a trip makes it the offer chat). `isLoading` is the
    /// estimate still loading; `isError` a failed request; `isEmptyView` an open chat with no offers.
    convenience init(
        isPreview: Bool = true,
        isLoading: Bool = false,
        isError: Bool = false,
        isEmptyView: Bool = false,
        trip: Trip? = nil,
        surge: SurgeContext = .none,
        withStops: Bool = false,
        isScheduled: Bool = false
    ) {
        self.init(
            rider: .mockRider(),
            draft: .mock(withStops: withStops),
            scheduledRidesStore: .mock(rides: []),
            repository: MockBookingRepository(),
            onTripMatched: { _ in },
            onScheduledRideConfirmed: {},
            onCancelled: {}
        )
        self.isPreview = isPreview
        var openTrip = trip
        if isEmptyView {
            openTrip = openTrip ?? .mockNegotiating()
            openTrip?.offers = []
        }
        self.trip = openTrip
        surgeContext = surge
        let hasFailedEstimate = isError && openTrip == nil
        suggestedFare = isLoading || hasFailedEstimate ? nil : .bdt(200)
        self.isLoading = isLoading
        if isError {
            errorMessage = openTrip == nil ? "Couldn't load the fare estimate. Please try again." : "Enter a valid fare amount"
        }
        if isScheduled {
            scheduledFor = Date().addingTimeInterval(24 * 3600)
        }
    }
}

#endif
