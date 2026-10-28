import Foundation

/// Options in the driver's "Cancel this trip" sheet (`DriverCancelTripScreen`).
public enum DriverCancellationReason: String, CaseIterable, Identifiable, Sendable {
    case riderNotAtPickup
    case unsafePickupLocation
    case vehicleIssue
    case changedPlans
    case other

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .riderNotAtPickup: return String(localized: "Rider not at pickup")
        case .unsafePickupLocation: return String(localized: "Unsafe pickup location")
        case .vehicleIssue: return String(localized: "Vehicle issue")
        case .changedPlans: return String(localized: "Changed plans")
        case .other: return String(localized: "Other")
        }
    }
}
