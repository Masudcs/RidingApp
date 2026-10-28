import Foundation

/// Trip lifecycle, in order: negotiating -> searchingDriver -> driverAssigned -> driverArriving
/// -> inProgress -> completed; `cancelled` can happen before `inProgress`.
public enum TripStatus: String, Codable, Sendable {
    case negotiating
    case searchingDriver
    case driverAssigned
    case driverArriving
    case inProgress
    case completed
    case cancelled
}

/// One offer in the InDrive-style negotiation thread. `proposedBy` distinguishes a rider's ask
/// from a driver's counter so the UI can render them on opposite sides of the thread.
public struct FareOffer: Identifiable, Equatable, Codable, Sendable {
    /// Who made the offer.
    public enum Author: String, Codable, Sendable {
        case rider
        case driver
    }

    public let id: String
    public let author: Author
    public let amount: Money
    public let createdAt: Date

    public init(id: String = UUID().uuidString, author: Author, amount: Money, createdAt: Date) {
        self.id = id
        self.author = author
        self.amount = amount
        self.createdAt = createdAt
    }
}

/// Rider-facing breakdown behind a surge multiplier, so the price bump is never a black box.
public struct SurgeContext: Equatable, Codable, Sendable {
    public let multiplier: Double
    public let reasons: [String]

    public init(multiplier: Double, reasons: [String]) {
        self.multiplier = multiplier
        self.reasons = reasons
    }

    public static let none = SurgeContext(multiplier: 1.0, reasons: [])
}

/// Snapshot of the matched driver and vehicle shown to the rider during pickup and the ride.
public struct TripDriverInfo: Equatable, Codable, Sendable {
    public let driverId: String
    public let name: String
    public let ratingAverage: Double
    public let vehicleType: VehicleType
    public let vehiclePlate: String
    public let etaMinutes: Int
    public let currentLocation: GeoPoint
    public let gender: Gender?

    public init(
        driverId: String,
        name: String,
        ratingAverage: Double,
        vehicleType: VehicleType,
        vehiclePlate: String,
        etaMinutes: Int,
        currentLocation: GeoPoint,
        gender: Gender? = nil
    ) {
        self.driverId = driverId
        self.name = name
        self.ratingAverage = ratingAverage
        self.vehicleType = vehicleType
        self.vehiclePlate = vehiclePlate
        self.etaMinutes = etaMinutes
        self.currentLocation = currentLocation
        self.gender = gender
    }
}

/// A per-trip micro-insurance premium bundled into the fare by default; Booking/Payments surface
/// it as a receipt line item rather than a separate purchase step.
public let defaultInsurancePremium = Money.bdt(3)

/// A ride from request to completion. Shared by booking (rider), incoming requests (driver) and
/// tracking. `agreedFare` is nil until an offer is accepted; use it over `suggestedFare` once set.
public struct Trip: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public var status: TripStatus
    public let vehicleType: VehicleType
    public let pickup: NamedLocation
    /// Intermediate stops in visit order, between `pickup` and `dropoff`.
    public let stops: [NamedLocation]
    public let dropoff: NamedLocation
    public let suggestedFare: Money
    public let surgeContext: SurgeContext
    public var offers: [FareOffer]
    public var agreedFare: Money?
    public var driver: TripDriverInfo?
    public let createdAt: Date
    public let insurancePremium: Money
    public let womenSafeModeRequested: Bool
    /// Empty for trips constructed before the rider identity was threaded through (e.g. a
    /// driver's incoming-request preview before a real rider is attached).
    public let riderId: String
    public let riderName: String
    /// Set the moment a driver is matched; drives the free-cancellation-window calculation.
    public var driverAssignedAt: Date?

    public init(
        id: String = UUID().uuidString,
        status: TripStatus = .negotiating,
        vehicleType: VehicleType,
        pickup: NamedLocation,
        stops: [NamedLocation] = [],
        dropoff: NamedLocation,
        suggestedFare: Money,
        surgeContext: SurgeContext = .none,
        offers: [FareOffer] = [],
        agreedFare: Money? = nil,
        driver: TripDriverInfo? = nil,
        createdAt: Date = Date(),
        insurancePremium: Money = defaultInsurancePremium,
        womenSafeModeRequested: Bool = false,
        riderId: String = "",
        riderName: String = "",
        driverAssignedAt: Date? = nil
    ) {
        self.id = id
        self.status = status
        self.vehicleType = vehicleType
        self.pickup = pickup
        self.stops = stops
        self.dropoff = dropoff
        self.suggestedFare = suggestedFare
        self.surgeContext = surgeContext
        self.offers = offers
        self.agreedFare = agreedFare
        self.driver = driver
        self.createdAt = createdAt
        self.insurancePremium = insurancePremium
        self.womenSafeModeRequested = womenSafeModeRequested
        self.riderId = riderId
        self.riderName = riderName
        self.driverAssignedAt = driverAssignedAt
    }
}

#if DEBUG

// Fixed fake data for SwiftUI previews. Debug builds only, so none of it ships.
// Defaults let a preview override just the field it is about.

public extension TripDriverInfo {
    static func mock(
        name: String = "Karim Rahman",
        vehicleType: VehicleType = .car,
        etaMinutes: Int = 4,
        gender: Gender? = .male
    ) -> TripDriverInfo {
        TripDriverInfo(
            driverId: "driver-1",
            name: name,
            ratingAverage: 4.9,
            vehicleType: vehicleType,
            vehiclePlate: "DHAKA-METRO-11-1234",
            etaMinutes: etaMinutes,
            currentLocation: GeoPoint(latitude: 23.7790, longitude: 90.4140),
            gender: gender
        )
    }
}

public extension FareOffer {
    static func mock(author: Author = .rider, taka: Double = 180) -> FareOffer {
        FareOffer(author: author, amount: .bdt(taka), createdAt: Date())
    }
}

public extension Trip {
    /// A trip in any lifecycle state. A driver is attached automatically once the status is past
    /// searching, so each stage's screen has what it needs.
    static func mock(
        status: TripStatus = .driverAssigned,
        vehicleType: VehicleType = .car,
        withStops: Bool = false,
        womenSafeModeRequested: Bool = false
    ) -> Trip {
        let hasDriver: Bool
        switch status {
        case .negotiating, .searchingDriver, .cancelled: hasDriver = false
        default: hasDriver = true
        }
        let agreed: Money? = hasDriver || status == .completed ? .bdt(220) : nil
        return Trip(
            id: "trip-1",
            status: status,
            vehicleType: vehicleType,
            pickup: .mockPickup(),
            stops: withStops ? [.mockStop()] : [],
            dropoff: .mockDropoff(),
            suggestedFare: .bdt(200),
            surgeContext: SurgeContext(multiplier: 1.0, reasons: []),
            offers: status == .negotiating ? [.mock(author: .rider, taka: 180), .mock(author: .driver, taka: 210)] : [],
            agreedFare: agreed,
            driver: hasDriver ? .mock(vehicleType: vehicleType) : nil,
            womenSafeModeRequested: womenSafeModeRequested,
            riderId: "rider-1",
            riderName: "Tania Ahmed",
            driverAssignedAt: hasDriver ? Date() : nil
        )
    }
}

#endif
