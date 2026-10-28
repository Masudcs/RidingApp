import Foundation

/// A rider-confirmed future pickup. Unlike an immediate booking, this skips live fare
/// negotiation entirely — the estimated fare captured at scheduling time becomes the agreed
/// fare once the ride actually starts, matching how most ride-hailing apps handle reservations.
public struct ScheduledRide: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let riderId: String
    public let riderName: String
    public let vehicleType: VehicleType
    public let pickup: NamedLocation
    public let stops: [NamedLocation]
    public let dropoff: NamedLocation
    /// Captured when scheduled; the real fare is not re-estimated at pickup time.
    public let estimatedFare: Money
    public let scheduledFor: Date

    public init(
        id: String = UUID().uuidString,
        riderId: String,
        riderName: String,
        vehicleType: VehicleType,
        pickup: NamedLocation,
        stops: [NamedLocation] = [],
        dropoff: NamedLocation,
        estimatedFare: Money,
        scheduledFor: Date
    ) {
        self.id = id
        self.riderId = riderId
        self.riderName = riderName
        self.vehicleType = vehicleType
        self.pickup = pickup
        self.stops = stops
        self.dropoff = dropoff
        self.estimatedFare = estimatedFare
        self.scheduledFor = scheduledFor
    }
}

#if DEBUG

// Fixed fake data for SwiftUI previews. Debug builds only, so none of it ships.
// Defaults let a preview override just the field it is about.

public extension ScheduledRide {
    static func mock(
        id: String = "scheduled-1",
        vehicleType: VehicleType = .car,
        pickup: NamedLocation = .mockPickup(),
        stops: [NamedLocation] = [],
        dropoff: NamedLocation = .mockDropoff(),
        taka: Double = 220,
        hoursFromNow: Double = 24
    ) -> ScheduledRide {
        ScheduledRide(
            id: id,
            riderId: "rider-1",
            riderName: "Tania Ahmed",
            vehicleType: vehicleType,
            pickup: pickup,
            stops: stops,
            dropoff: dropoff,
            estimatedFare: .bdt(taka),
            scheduledFor: Date().addingTimeInterval(hoursFromNow * 3600)
        )
    }

    static func mockList() -> [ScheduledRide] {
        [
            .mock(id: "scheduled-1", hoursFromNow: 24),
            .mock(id: "scheduled-2", vehicleType: .bike, pickup: .mockDropoff(), dropoff: .mockPickup(), taka: 90, hoursFromNow: 48)
        ]
    }

    /// Overlong place names, to check truncation.
    static func mockLongText() -> ScheduledRide {
        .mock(
            id: "scheduled-long",
            pickup: NamedLocation(
                id: "long-pickup",
                title: "Bangabandhu International Conference Center, Agargaon Administrative Area",
                subtitle: "Sher-e-Bangla Nagar, Dhaka",
                point: .mockPickup
            ),
            dropoff: NamedLocation(
                id: "long-dropoff",
                title: "Hazrat Shahjalal International Airport, Terminal 3 Departure Level",
                subtitle: "Airport Road, Dhaka",
                point: .mockDropoff
            ),
            taka: 1450
        )
    }
}

#endif
