import Foundation

/// Real-backend implementation of `IBookingRepository`. Each method maps to one endpoint under
/// `booking/` (or `driver/`) and lets `APIClient` errors propagate to the ViewModel.
public final class BookingRepository: IBookingRepository {
    private let client: APIClient
    private let encoder = JSONEncoder()

    public init(client: APIClient) {
        self.client = client
    }

    /// Mock in Dev/Staging so the app keeps working offline; the real backend otherwise.
    public static func makeDefault(environment: AppEnvironment = .current) -> IBookingRepository {
        if environment.usesMockServices {
            return MockBookingRepository()
        }
        return BookingRepository(client: APIClientFactory.make(baseURL: environment.apiBaseURL))
    }

    public func nearbyPickupSuggestions() async throws -> [NamedLocation] {
        try await client.send(Endpoint(path: "booking/pickup-suggestions"))
    }

    public func dropoffSuggestions(near pickup: NamedLocation) async throws -> [NamedLocation] {
        try await client.send(Endpoint(path: "booking/dropoff-suggestions", method: .post, body: try encoder.encode(pickup)))
    }

    public func estimateFare(
        vehicleType: VehicleType,
        pickup: NamedLocation,
        stops: [NamedLocation],
        dropoff: NamedLocation
    ) async throws -> (suggestedFare: Money, surge: SurgeContext) {
        let body = FareEstimateRequest(vehicleType: vehicleType, pickup: pickup, stops: stops, dropoff: dropoff)
        let response: FareEstimateResponse = try await client.send(
            Endpoint(path: "booking/fare-estimate", method: .post, body: try encoder.encode(body))
        )
        return (response.suggestedFare, response.surge)
    }

    public func createNegotiation(
        vehicleType: VehicleType,
        pickup: NamedLocation,
        stops: [NamedLocation],
        dropoff: NamedLocation,
        suggestedFare: Money,
        surge: SurgeContext,
        womenSafeModeRequested: Bool,
        riderId: String,
        riderName: String
    ) async throws -> Trip {
        let body = CreateNegotiationRequest(
            vehicleType: vehicleType,
            pickup: pickup,
            stops: stops,
            dropoff: dropoff,
            suggestedFare: suggestedFare,
            surge: surge,
            womenSafeModeRequested: womenSafeModeRequested,
            riderId: riderId,
            riderName: riderName
        )
        return try await client.send(Endpoint(path: "booking/negotiations", method: .post, body: try encoder.encode(body)))
    }

    public func submitRiderOffer(tripId: String, amount: Money) async throws -> Trip {
        try await client.send(Endpoint(path: "booking/negotiations/\(tripId.pathEscaped)/offers", method: .post, body: try encoder.encode(amount)))
    }

    public func respondToOffer(tripId: String, response: OfferResponse) async throws -> Trip {
        let body: OfferResponseRequest
        switch response {
        case .accept: body = OfferResponseRequest(action: "accept", amount: nil)
        case .counter(let amount): body = OfferResponseRequest(action: "counter", amount: amount)
        case .decline: body = OfferResponseRequest(action: "decline", amount: nil)
        }
        return try await client.send(Endpoint(path: "booking/negotiations/\(tripId.pathEscaped)/respond", method: .post, body: try encoder.encode(body)))
    }

    public func riderAcceptsOffer(tripId: String) async throws -> Trip {
        try await client.send(Endpoint(path: "booking/negotiations/\(tripId.pathEscaped)/accept", method: .post))
    }

    public func incomingRequestsForDriver() async throws -> [Trip] {
        try await client.send(Endpoint(path: "driver/incoming-requests"))
    }

    public func cancelNegotiation(tripId: String, reason: String, fee: Money) async throws {
        let body = CancelNegotiationRequest(reason: reason, fee: fee)
        let _: EmptyResponse = try await client.send(
            Endpoint(path: "booking/negotiations/\(tripId.pathEscaped)/cancel", method: .post, body: try encoder.encode(body))
        )
    }

    /// Best effort: the protocol method can't throw, so a failed sync is dropped and the next
    /// booking just won't apply the latest favorites/blocks until the following sync.
    public func setDriverPreferences(favoriteDriverIds: Set<String>, blockedDriverIds: Set<String>) async {
        let body = DriverPreferencesRequest(favoriteDriverIds: favoriteDriverIds.sorted(), blockedDriverIds: blockedDriverIds.sorted())
        guard let data = try? encoder.encode(body) else { return }
        let _: EmptyResponse? = try? await client.send(Endpoint(path: "booking/driver-preferences", method: .put, body: data))
    }
}

/// For endpoints whose response body is ignored.
private struct EmptyResponse: Decodable {}

/// Body for `booking/fare-estimate`.
private struct FareEstimateRequest: Encodable {
    let vehicleType: VehicleType
    let pickup: NamedLocation
    let stops: [NamedLocation]
    let dropoff: NamedLocation
}

/// Response from `booking/fare-estimate`.
private struct FareEstimateResponse: Decodable {
    let suggestedFare: Money
    let surge: SurgeContext
}

/// Body for `booking/negotiations`.
private struct CreateNegotiationRequest: Encodable {
    let vehicleType: VehicleType
    let pickup: NamedLocation
    let stops: [NamedLocation]
    let dropoff: NamedLocation
    let suggestedFare: Money
    let surge: SurgeContext
    let womenSafeModeRequested: Bool
    let riderId: String
    let riderName: String
}

/// Body for `booking/negotiations/{id}/respond`. `action` is accept, counter or decline; `amount` is set only for a counter.
private struct OfferResponseRequest: Encodable {
    let action: String
    let amount: Money?
}

/// Body for `booking/negotiations/{id}/cancel`.
private struct CancelNegotiationRequest: Encodable {
    let reason: String
    let fee: Money
}

/// Body for `booking/driver-preferences`. IDs are sorted so the payload is stable.
private struct DriverPreferencesRequest: Encodable {
    let favoriteDriverIds: [String]
    let blockedDriverIds: [String]
}
