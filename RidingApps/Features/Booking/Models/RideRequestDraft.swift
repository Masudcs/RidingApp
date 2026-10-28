import Foundation

/// The rider's route choices, handed from the location step to the fare step as plain values.
/// Also the navigation value for the fare step, hence `Hashable`.
public struct RideRequestDraft: Hashable, Sendable {
    public let vehicleType: VehicleType
    public let pickup: NamedLocation
    public let stops: [NamedLocation]
    public let dropoff: NamedLocation

    public init(vehicleType: VehicleType, pickup: NamedLocation, stops: [NamedLocation], dropoff: NamedLocation) {
        self.vehicleType = vehicleType
        self.pickup = pickup
        self.stops = stops
        self.dropoff = dropoff
    }
}

#if DEBUG

// Fixed fake data for SwiftUI previews. Debug builds only, so none of it ships.
// Defaults let a preview override just the field it is about.

public extension RideRequestDraft {
    static func mock(vehicleType: VehicleType = .car, withStops: Bool = false) -> RideRequestDraft {
        RideRequestDraft(
            vehicleType: vehicleType,
            pickup: .mockPickup(),
            stops: withStops ? [.mockStop()] : [],
            dropoff: .mockDropoff()
        )
    }
}

#endif
