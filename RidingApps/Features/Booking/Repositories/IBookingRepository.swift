/// Everything the booking flow needs from the backend: location suggestions, fare estimate,
/// the rider/driver price negotiation, and cancellation. `MockBookingRepository` is used offline.
/// All trip-returning calls return the full updated `Trip`; callers replace their copy.
public protocol IBookingRepository: Sendable {
    /// Quick-pick pickup places for the location step.
    func nearbyPickupSuggestions() async throws -> [NamedLocation]
    /// Quick-pick dropoff places, nearest to the chosen pickup first.
    func dropoffSuggestions(near pickup: NamedLocation) async throws -> [NamedLocation]
    /// Suggested price plus any surge for the route. Shown before the rider requests the ride.
    func estimateFare(vehicleType: VehicleType, pickup: NamedLocation, stops: [NamedLocation], dropoff: NamedLocation) async throws -> (suggestedFare: Money, surge: SurgeContext)
    /// Opens a negotiation, seeded with the rider's first offer at the suggested fare.
    func createNegotiation(vehicleType: VehicleType, pickup: NamedLocation, stops: [NamedLocation], dropoff: NamedLocation, suggestedFare: Money, surge: SurgeContext, womenSafeModeRequested: Bool, riderId: String, riderName: String) async throws -> Trip
    /// Rider proposes a new price; the driver may counter or accept.
    func submitRiderOffer(tripId: String, amount: Money) async throws -> Trip
    /// Driver side: accept, counter or decline the rider's latest offer.
    func respondToOffer(tripId: String, response: OfferResponse) async throws -> Trip
    /// Rider accepts the driver's latest counter; the trip should come back as `.driverAssigned`.
    func riderAcceptsOffer(tripId: String) async throws -> Trip
    /// Driver side: open requests to show as cards.
    func incomingRequestsForDriver() async throws -> [Trip]
    /// Rider cancels. `fee` is what the app showed the rider; the backend should still decide the real fee.
    func cancelNegotiation(tripId: String, reason: String, fee: Money) async throws
    /// Biases future matches toward favorites and excludes blocked drivers entirely.
    func setDriverPreferences(favoriteDriverIds: Set<String>, blockedDriverIds: Set<String>) async
}

public extension IBookingRepository {
    /// Old call sites that estimate without stops still compile.
    func estimateFare(vehicleType: VehicleType, pickup: NamedLocation, dropoff: NamedLocation) async throws -> (suggestedFare: Money, surge: SurgeContext) {
        try await estimateFare(vehicleType: vehicleType, pickup: pickup, stops: [], dropoff: dropoff)
    }
}

public extension IBookingRepository {
    /// Old call sites that cancel without a reason/fee (e.g. tests) still compile.
    func cancelNegotiation(tripId: String) async throws {
        try await cancelNegotiation(tripId: tripId, reason: CancellationReason.other.displayName, fee: .bdt(0))
    }
}

public extension IBookingRepository {
    /// Swift protocol requirements can't declare default argument values, so these overloads
    /// keep existing call sites (that don't care about stops, Women Safe Mode, and/or rider
    /// identity) source-compatible.
    func createNegotiation(
        vehicleType: VehicleType,
        pickup: NamedLocation,
        dropoff: NamedLocation,
        suggestedFare: Money,
        surge: SurgeContext,
        womenSafeModeRequested: Bool,
        riderId: String,
        riderName: String
    ) async throws -> Trip {
        try await createNegotiation(
            vehicleType: vehicleType,
            pickup: pickup,
            stops: [],
            dropoff: dropoff,
            suggestedFare: suggestedFare,
            surge: surge,
            womenSafeModeRequested: womenSafeModeRequested,
            riderId: riderId,
            riderName: riderName
        )
    }

    func createNegotiation(
        vehicleType: VehicleType,
        pickup: NamedLocation,
        dropoff: NamedLocation,
        suggestedFare: Money,
        surge: SurgeContext,
        womenSafeModeRequested: Bool
    ) async throws -> Trip {
        try await createNegotiation(
            vehicleType: vehicleType,
            pickup: pickup,
            dropoff: dropoff,
            suggestedFare: suggestedFare,
            surge: surge,
            womenSafeModeRequested: womenSafeModeRequested,
            riderId: "",
            riderName: ""
        )
    }

    func createNegotiation(
        vehicleType: VehicleType,
        pickup: NamedLocation,
        dropoff: NamedLocation,
        suggestedFare: Money,
        surge: SurgeContext
    ) async throws -> Trip {
        try await createNegotiation(
            vehicleType: vehicleType,
            pickup: pickup,
            dropoff: dropoff,
            suggestedFare: suggestedFare,
            surge: surge,
            womenSafeModeRequested: false
        )
    }
}
