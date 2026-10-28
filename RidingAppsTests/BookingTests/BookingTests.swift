import Testing
@testable import RidingApps
import Foundation

@Test func estimateFareIsAtLeastBaseFare() async throws {
    let service = MockBookingRepository()
    let pickup = try await service.nearbyPickupSuggestions()[0]
    let dropoff = try await service.dropoffSuggestions(near: pickup)[0]

    let result = try await service.estimateFare(vehicleType: .car, pickup: pickup, dropoff: dropoff)

    #expect(result.suggestedFare >= VehicleType.car.baseFare)
}

@Test func driverCanRespondToAGeneratedIncomingRequest() async throws {
    let service = MockBookingRepository()
    let requests = try await service.incomingRequestsForDriver()
    let request = try #require(requests.first)

    let updated = try await service.respondToOffer(tripId: request.id, response: .accept)

    #expect(updated.status == .driverAssigned)
    #expect(updated.driver != nil)
}

@Test func negotiationRoundTripAssignsAgreedFareOrCounterOffer() async throws {
    let service = MockBookingRepository()
    let pickup = try await service.nearbyPickupSuggestions()[0]
    let dropoff = try await service.dropoffSuggestions(near: pickup)[0]
    let estimate = try await service.estimateFare(vehicleType: .bike, pickup: pickup, dropoff: dropoff)

    let trip = try await service.createNegotiation(
        vehicleType: .bike,
        pickup: pickup,
        dropoff: dropoff,
        suggestedFare: estimate.suggestedFare,
        surge: estimate.surge
    )
    #expect(trip.status == .negotiating)
    #expect(trip.offers.count == 1)

    let riderOfferAmount = Money.bdt(trip.suggestedFare.majorUnits * 0.9)
    let updated = try await service.submitRiderOffer(tripId: trip.id, amount: riderOfferAmount)

    #expect(updated.offers.count >= 2)
    #expect(updated.status == .driverAssigned || updated.status == .searchingDriver || updated.offers.last?.author == .driver)

    if updated.status == .driverAssigned {
        #expect(updated.agreedFare == riderOfferAmount)
        #expect(updated.driver != nil)
    }
}

@Test func womenSafeModeNegotiationAlwaysMatchesADriver() async throws {
    let service = MockBookingRepository()
    let pickup = try await service.nearbyPickupSuggestions()[0]
    let dropoff = try await service.dropoffSuggestions(near: pickup)[0]
    let estimate = try await service.estimateFare(vehicleType: .car, pickup: pickup, dropoff: dropoff)

    let trip = try await service.createNegotiation(
        vehicleType: .car,
        pickup: pickup,
        dropoff: dropoff,
        suggestedFare: estimate.suggestedFare,
        surge: estimate.surge,
        womenSafeModeRequested: true
    )
    #expect(trip.womenSafeModeRequested)
    #expect(trip.insurancePremium == defaultInsurancePremium)

    let matched = try await service.riderAcceptsOffer(tripId: trip.id)

    #expect(matched.status == .driverAssigned)
    #expect(matched.driver != nil)
}

@Test func cancelNegotiationRemovesTrip() async throws {
    let service = MockBookingRepository()
    let pickup = try await service.nearbyPickupSuggestions()[0]
    let dropoff = try await service.dropoffSuggestions(near: pickup)[0]
    let estimate = try await service.estimateFare(vehicleType: .cng, pickup: pickup, dropoff: dropoff)
    let trip = try await service.createNegotiation(
        vehicleType: .cng,
        pickup: pickup,
        dropoff: dropoff,
        suggestedFare: estimate.suggestedFare,
        surge: estimate.surge
    )

    try await service.cancelNegotiation(tripId: trip.id)

    await #expect(throws: BookingError.tripNotFound) {
        _ = try await service.submitRiderOffer(tripId: trip.id, amount: trip.suggestedFare)
    }
}

@Test func cancellationIsFreeBeforeADriverIsMatched() throws {
    let trip = Trip(
        status: .negotiating,
        vehicleType: .car,
        pickup: NamedLocation(title: "A", subtitle: "", point: GeoPoint(latitude: 0, longitude: 0)),
        dropoff: NamedLocation(title: "B", subtitle: "", point: GeoPoint(latitude: 0, longitude: 0)),
        suggestedFare: .bdt(100)
    )

    let quote = CancellationPolicy.quote(for: trip)
    #expect(quote.isFree)
    #expect(quote.fee == .bdt(0))
}

@Test func cancellationFeeAppliesAfterFreeWindowElapses() throws {
    var trip = Trip(
        status: .driverAssigned,
        vehicleType: .car,
        pickup: NamedLocation(title: "A", subtitle: "", point: GeoPoint(latitude: 0, longitude: 0)),
        dropoff: NamedLocation(title: "B", subtitle: "", point: GeoPoint(latitude: 0, longitude: 0)),
        suggestedFare: .bdt(100)
    )
    let assignedAt = Date(timeIntervalSince1970: 0)
    trip.driverAssignedAt = assignedAt

    let withinWindow = CancellationPolicy.quote(for: trip, now: assignedAt.addingTimeInterval(30))
    #expect(withinWindow.isFree)

    let afterWindow = CancellationPolicy.quote(for: trip, now: assignedAt.addingTimeInterval(200))
    #expect(!afterWindow.isFree)
    #expect(afterWindow.fee == CancellationPolicy.lateFee)
}

@Test func multiStopFareExceedsDirectFareByMoreThanJustDistance() async throws {
    let service = MockBookingRepository()
    let pickup = try await service.nearbyPickupSuggestions()[0]
    let dropoff = try await service.dropoffSuggestions(near: pickup)[0]
    let stop = try await service.dropoffSuggestions(near: pickup)[1]

    let direct = try await service.estimateFare(vehicleType: .car, pickup: pickup, dropoff: dropoff)
    let withStop = try await service.estimateFare(vehicleType: .car, pickup: pickup, stops: [stop], dropoff: dropoff)

    // Only compare when neither leg randomly surged, otherwise the multiplier dominates the diff.
    if direct.surge == .none && withStop.surge == .none {
        #expect(withStop.suggestedFare > direct.suggestedFare)
    }
}

@Test func createNegotiationPreservesStopsOnTheTrip() async throws {
    let service = MockBookingRepository()
    let pickup = try await service.nearbyPickupSuggestions()[0]
    let dropoff = try await service.dropoffSuggestions(near: pickup)[0]
    let stop = try await service.dropoffSuggestions(near: pickup)[1]
    let estimate = try await service.estimateFare(vehicleType: .car, pickup: pickup, stops: [stop], dropoff: dropoff)

    let trip = try await service.createNegotiation(
        vehicleType: .car,
        pickup: pickup,
        stops: [stop],
        dropoff: dropoff,
        suggestedFare: estimate.suggestedFare,
        surge: estimate.surge,
        womenSafeModeRequested: false,
        riderId: "rider-1",
        riderName: "Tania Ahmed"
    )

    #expect(trip.stops == [stop])
}

@MainActor
@Test func scheduledRidesStoreKeepsRidesSortedByTime() throws {
    let suiteName = "test.scheduledRides.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = ScheduledRidesStore(defaults: defaults)
    let pickup = NamedLocation(title: "A", subtitle: "", point: GeoPoint(latitude: 0, longitude: 0))
    let dropoff = NamedLocation(title: "B", subtitle: "", point: GeoPoint(latitude: 0, longitude: 0))
    let later = ScheduledRide(riderId: "r1", riderName: "Tania", vehicleType: .car, pickup: pickup, dropoff: dropoff, estimatedFare: .bdt(100), scheduledFor: Date(timeIntervalSince1970: 2_000))
    let sooner = ScheduledRide(riderId: "r1", riderName: "Tania", vehicleType: .car, pickup: pickup, dropoff: dropoff, estimatedFare: .bdt(100), scheduledFor: Date(timeIntervalSince1970: 1_000))

    store.add(later)
    store.add(sooner)

    #expect(store.rides.map(\.id) == [sooner.id, later.id])

    store.remove(id: sooner.id)
    #expect(store.rides.map(\.id) == [later.id])
}

@MainActor
@Test func startingAScheduledRideNowSkipsNegotiationAndMatchesAtTheEstimatedFare() async throws {
    let suiteName = "test.scheduledRides.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = ScheduledRidesStore(defaults: defaults)
    let service = MockBookingRepository()
    let pickup = try await service.nearbyPickupSuggestions()[0]
    let dropoff = try await service.dropoffSuggestions(near: pickup)[0]
    let ride = ScheduledRide(riderId: "rider-1", riderName: "Tania Ahmed", vehicleType: .car, pickup: pickup, dropoff: dropoff, estimatedFare: .bdt(250), scheduledFor: Date())
    store.add(ride)

    var matched: Trip?
    let viewModel = ScheduledRidesViewModel(store: store, repository: service) { matched = $0 }
    #expect(viewModel.rides.map(\.id) == [ride.id])

    viewModel.didTapStartNow(ride)
    #expect(viewModel.isStarting)
    try await waitUntil { matched != nil }

    let trip = try #require(matched)
    #expect(trip.status == .driverAssigned)
    #expect(trip.agreedFare == .bdt(250))
    #expect(trip.driver != nil)
    #expect(!viewModel.isStarting)
    #expect(viewModel.errorMessage == nil)
    // The started ride leaves the schedule.
    #expect(store.rides.isEmpty)
    #expect(viewModel.rides.isEmpty)
}

@Test func blockedDriversAreNeverMatched() async throws {
    let service = MockBookingRepository()
    let pickup = try await service.nearbyPickupSuggestions()[0]
    let dropoff = try await service.dropoffSuggestions(near: pickup)[0]

    // Block every driver except one, so matching is forced onto the sole survivor.
    let allExceptOne: Set<String> = ["drv-abul", "drv-selim", "drv-jasim", "drv-rafiq", "drv-nasrin", "drv-farida", "drv-shirin", "drv-ruma", "drv-taslima"]
    await service.setDriverPreferences(favoriteDriverIds: [], blockedDriverIds: allExceptOne)

    let trip = try await service.createNegotiation(
        vehicleType: .car,
        pickup: pickup,
        dropoff: dropoff,
        suggestedFare: .bdt(150),
        surge: .none
    )
    let matched = try await service.riderAcceptsOffer(tripId: trip.id)

    #expect(matched.driver?.driverId == "drv-karim")
}

// MARK: - Trip stage persistence

private func makeStageTrip(startedAt: Date = Date()) -> Trip {
    let point = GeoPoint(latitude: 23.8, longitude: 90.4)
    return Trip(
        status: .inProgress,
        vehicleType: .car,
        pickup: NamedLocation(title: "A", subtitle: "", point: point),
        dropoff: NamedLocation(title: "B", subtitle: "", point: point),
        suggestedFare: .bdt(200),
        agreedFare: .bdt(220),
        driver: TripDriverInfo(driverId: "d1", name: "Karim", ratingAverage: 4.8, vehicleType: .car, vehiclePlate: "DHA-1", etaMinutes: 3, currentLocation: point),
        createdAt: startedAt,
        riderId: "r1",
        riderName: "Tania",
        driverAssignedAt: startedAt
    )
}

private func makeStageReceipt(for trip: Trip) -> PaymentReceipt {
    PaymentReceipt(tripId: trip.id, method: .cash, amount: .bdt(220), status: .captured)
}

@Test func tripStageStoreRoundTripsPerUserAndRole() throws {
    let suiteName = "test.tripStage.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = TripStageStore(defaults: defaults)
    let trip = makeStageTrip()

    store.save(TripStageSnapshot(stage: .active, trip: trip), role: .rider, userId: "u1")

    #expect(store.load(role: .rider, userId: "u1")?.trip == trip)
    #expect(store.load(role: .rider, userId: "u2") == nil)
    #expect(store.load(role: .driver, userId: "u1") == nil)

    store.save(TripStageSnapshot(stage: .awaitingRating, trip: trip), role: .driver, userId: "u1")
    store.clear(for: "u1")
    #expect(store.load(role: .rider, userId: "u1") == nil)
    #expect(store.load(role: .driver, userId: "u1") == nil)
}

@Test func tripStageStoreDiscardsStaleTrips() throws {
    let suiteName = "test.tripStage.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let now = Date()
    let store = TripStageStore(defaults: defaults, now: { now })
    let old = makeStageTrip(startedAt: now.addingTimeInterval(-TripStageStore.maxTripAge - 60))
    let fresh = makeStageTrip(startedAt: now.addingTimeInterval(-60))

    store.save(TripStageSnapshot(stage: .active, trip: old), role: .rider, userId: "u1")
    #expect(store.load(role: .rider, userId: "u1") == nil)

    store.save(TripStageSnapshot(stage: .active, trip: fresh), role: .rider, userId: "u1")
    #expect(store.load(role: .rider, userId: "u1") != nil)
}

@Test func tripStageStoreDiscardsCorruptData() throws {
    let suiteName = "test.tripStage.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = TripStageStore(defaults: defaults)
    defaults.set(Data("not json".utf8), forKey: "tripStage.rider.u1")

    #expect(store.load(role: .rider, userId: "u1") == nil)
    #expect(defaults.data(forKey: "tripStage.rider.u1") == nil)
    #expect(defaults.data(forKey: "tripStage.rider.u1.corrupt") == nil)
}

@MainActor
private func makeRiderHomeViewModel(rider: AppUser, defaults: UserDefaults) -> RiderHomeViewModel {
    RiderHomeViewModel(
        rider: rider,
        loyaltyStore: LoyaltyStore(userId: rider.id, defaults: defaults),
        bookingRepository: MockBookingRepository(),
        safetyRepository: MockSafetyRepository.shared,
        tripStageStore: TripStageStore(defaults: defaults)
    )
}

@MainActor
@Test func riderHomeRestoresEachTripStageAfterRelaunch() throws {
    let suiteName = "test.riderHome.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let rider = AppUser(fullName: "Tania", phoneNumber: "+8801700000000", role: .rider)
    let trip = makeStageTrip()
    let receipt = makeStageReceipt(for: trip)

    let first = makeRiderHomeViewModel(rider: rider, defaults: defaults)
    #expect(first.activeTrip == nil)

    first.didMatchTrip(trip)
    let tracking = makeRiderHomeViewModel(rider: rider, defaults: defaults)
    #expect(tracking.activeTrip == trip)

    first.didCompleteTrip()
    let awaitingPayment = makeRiderHomeViewModel(rider: rider, defaults: defaults)
    #expect(awaitingPayment.completedTrip == trip)
    #expect(awaitingPayment.activeTrip == nil)

    first.didCompletePayment(for: trip, receipt: receipt, recordRide: { _ in })
    let awaitingRating = makeRiderHomeViewModel(rider: rider, defaults: defaults)
    #expect(awaitingRating.tripToRate == trip)
    #expect(awaitingRating.lastReceipt == receipt)
    #expect(awaitingRating.completedTrip == nil)

    first.didFinishRating()
    let showingReceipt = makeRiderHomeViewModel(rider: rider, defaults: defaults)
    #expect(showingReceipt.tripToRate == nil)
    #expect(showingReceipt.lastReceipt == receipt)

    first.didDismissReceipt()
    let booking = makeRiderHomeViewModel(rider: rider, defaults: defaults)
    #expect(booking.activeTrip == nil)
    #expect(booking.completedTrip == nil)
    #expect(booking.tripToRate == nil)
    #expect(booking.lastReceipt == nil)
}

@MainActor
@Test func riderHomeDoesNotRestoreAnotherUsersTrip() throws {
    let suiteName = "test.riderHome.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let rider = AppUser(fullName: "Tania", phoneNumber: "+8801700000000", role: .rider)
    let other = AppUser(fullName: "Rahim", phoneNumber: "+8801700000001", role: .rider)

    makeRiderHomeViewModel(rider: rider, defaults: defaults).didMatchTrip(makeStageTrip())

    #expect(makeRiderHomeViewModel(rider: other, defaults: defaults).activeTrip == nil)
}

@MainActor
@Test func driverHomeRestoresActiveTripAndRatingStageButStaysOffline() throws {
    let suiteName = "test.driverHome.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let trip = makeStageTrip()
    func makeViewModel() -> DriverHomeViewModel {
        DriverHomeViewModel(
            driverId: "driver-1",
            service: MockBookingRepository(),
            safetyRepository: MockSafetyRepository.shared,
            tripStageStore: TripStageStore(defaults: defaults)
        )
    }
    // Seed an active trip as if the driver had accepted it before the app was killed.
    TripStageStore(defaults: defaults).save(TripStageSnapshot(stage: .active, trip: trip), role: .driver, userId: "driver-1")

    let active = makeViewModel()
    #expect(active.activeTrip == trip)
    #expect(active.isOnline == false)

    active.handleTripCompleted()
    let rating = makeViewModel()
    #expect(rating.tripPendingRating == trip)
    #expect(rating.activeTrip == nil)

    rating.finishRatingRider()
    let idle = makeViewModel()
    #expect(idle.activeTrip == nil)
    #expect(idle.tripPendingRating == nil)
}

// MARK: - Cancellation double-confirm guard

private func makeCancellationTestTrip() -> Trip {
    Trip(
        vehicleType: .car,
        pickup: NamedLocation(title: "A", subtitle: "", point: GeoPoint(latitude: 23.78, longitude: 90.41)),
        dropoff: NamedLocation(title: "B", subtitle: "", point: GeoPoint(latitude: 23.79, longitude: 90.40)),
        suggestedFare: .bdt(150)
    )
}

@MainActor
@Test func cancellationConfirmFiresOnceUntilTheCallerReportsAFailure() {
    var confirmCount = 0
    let viewModel = CancellationViewModel(trip: makeCancellationTestTrip(), onConfirm: { _, _ in confirmCount += 1 }, onKeepRide: {})

    viewModel.didTapConfirm()
    viewModel.didTapConfirm()
    #expect(confirmCount == 1)
    #expect(viewModel.isConfirming)

    viewModel.didFailConfirmation()
    #expect(!viewModel.isConfirming)
    viewModel.didTapConfirm()
    #expect(confirmCount == 2)
}

@MainActor
@Test func driverCancelConfirmFiresOnceUntilTheCallerReportsAFailure() {
    var confirmCount = 0
    let viewModel = DriverCancelTripViewModel(onConfirm: { _ in confirmCount += 1 }, onKeepTrip: {})

    viewModel.didTapConfirm()
    viewModel.didTapConfirm()
    #expect(confirmCount == 1)

    viewModel.didFailConfirmation()
    viewModel.didTapConfirm()
    #expect(confirmCount == 2)
}
