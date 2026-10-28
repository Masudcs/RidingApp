import Foundation

/// The Phase 1 vehicle classes plus a premium tier. Ordering here drives display order in
/// vehicle pickers.
public enum VehicleType: String, CaseIterable, Codable, Sendable, Identifiable {
    case bike
    case car
    case cng
    case premium

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .bike: return String(localized: "Bike")
        case .car: return String(localized: "Car")
        case .cng: return String(localized: "CNG / Auto")
        case .premium: return String(localized: "Premium")
        }
    }

    public var systemImageName: String {
        switch self {
        case .bike: return "bicycle"
        case .car: return "car.fill"
        case .cng: return "car.side.rear.open"
        case .premium: return "car.rear.fill"
        }
    }

    /// Max passengers.
    public var capacity: Int {
        switch self {
        case .bike: return 1
        case .car: return 4
        case .cng: return 3
        case .premium: return 4
        }
    }

    /// Base fare per kilometer used by the mock pricing engine.
    public var baseFarePerKm: Money {
        switch self {
        case .bike: return .bdt(15)
        case .car: return .bdt(35)
        case .cng: return .bdt(22)
        case .premium: return .bdt(60)
        }
    }

    /// Flat starting fare added to the per-km charge in the mock pricing engine.
    public var baseFare: Money {
        switch self {
        case .bike: return .bdt(20)
        case .car: return .bdt(50)
        case .cng: return .bdt(30)
        case .premium: return .bdt(100)
        }
    }
}
