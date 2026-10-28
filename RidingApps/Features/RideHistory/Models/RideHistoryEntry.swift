import Foundation

/// One completed (or cancelled) trip as it appears in a specific user's own history — the same
/// underlying `Trip` produces one entry for the rider and a separate entry for the driver, each
/// naming the other party as the counterpart.
public struct RideHistoryEntry: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let ownerId: String
    public let tripId: String
    /// The owner's role in this trip (not the counterpart's).
    public let role: UserRole
    public let counterpartName: String
    public let vehicleType: VehicleType
    public let pickupTitle: String
    public let dropoffTitle: String
    /// Saved as-is at completion; later fare changes don't alter history.
    public let fare: Money
    public let status: TripStatus
    public let completedAt: Date

    public init(
        id: String = UUID().uuidString,
        ownerId: String,
        tripId: String,
        role: UserRole,
        counterpartName: String,
        vehicleType: VehicleType,
        pickupTitle: String,
        dropoffTitle: String,
        fare: Money,
        status: TripStatus,
        completedAt: Date = Date()
    ) {
        self.id = id
        self.ownerId = ownerId
        self.tripId = tripId
        self.role = role
        self.counterpartName = counterpartName
        self.vehicleType = vehicleType
        self.pickupTitle = pickupTitle
        self.dropoffTitle = dropoffTitle
        self.fare = fare
        self.status = status
        self.completedAt = completedAt
    }
}

#if DEBUG

// Fixed fake data for SwiftUI previews. Debug builds only, so none of it ships.
// Defaults let a preview override just the field it is about.

public extension RideHistoryEntry {
    static func mock(
        id: String = "history-1",
        ownerId: String = "preview-user",
        role: UserRole = .rider,
        status: TripStatus = .completed,
        vehicleType: VehicleType = .car,
        pickupTitle: String = "Gulshan 1",
        dropoffTitle: String = "Dhanmondi 27",
        daysAgo: Int = 1
    ) -> RideHistoryEntry {
        RideHistoryEntry(
            id: id,
            ownerId: ownerId,
            tripId: "trip-\(id)",
            role: role,
            counterpartName: role == .rider ? "Karim Rahman" : "Tania Ahmed",
            vehicleType: vehicleType,
            pickupTitle: pickupTitle,
            dropoffTitle: dropoffTitle,
            fare: .bdt(220),
            status: status,
            completedAt: Date().addingTimeInterval(-Double(daysAgo) * 86_400)
        )
    }

    /// A mix of completed and cancelled rides, and of rider and driver entries, for one owner.
    static func mockList(ownerId: String = "preview-user") -> [RideHistoryEntry] {
        [
            .mock(id: "history-1", ownerId: ownerId, role: .rider, daysAgo: 1),
            .mock(id: "history-2", ownerId: ownerId, role: .rider, status: .cancelled, vehicleType: .bike, pickupTitle: "Banani", dropoffTitle: "Uttara", daysAgo: 4),
            .mock(id: "history-3", ownerId: ownerId, role: .driver, vehicleType: .cng, pickupTitle: "Motijheel", dropoffTitle: "Mirpur 10", daysAgo: 9)
        ]
    }
}

#endif
