import Foundation

/// Why a rider cancelled — captured for the trip record even when the cancellation is free,
/// since driver-side patterns (e.g. repeated "driver not moving") are useful signal later.
public enum CancellationReason: String, Codable, Sendable, CaseIterable, Identifiable {
    case changedMyMind
    case foundAnotherRide
    case driverTakingTooLong
    case driverNotMoving
    case wrongPickupLocation
    case safetyConcern
    case other

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .changedMyMind: return String(localized: "Changed my mind")
        case .foundAnotherRide: return String(localized: "Found another ride")
        case .driverTakingTooLong: return String(localized: "Driver is taking too long")
        case .driverNotMoving: return String(localized: "Driver isn't moving")
        case .wrongPickupLocation: return String(localized: "Wrong pickup location")
        case .safetyConcern: return String(localized: "Safety concern")
        case .other: return String(localized: "Other")
        }
    }
}

/// What cancelling costs right now, plus the sentence shown to the rider.
public struct CancellationQuote: Equatable, Sendable {
    public let fee: Money
    public let isFree: Bool
    public let explanation: String
}

/// Free-cancellation-window rules for the rider-initiated "Cancel ride" flow. Before a driver is
/// matched, cancelling is always free; once matched, the rider has a short grace period before a
/// flat fee applies (mirrors why most ride-hailing apps only charge once a driver has committed).
public enum CancellationPolicy {
    /// Seconds after a driver is assigned during which cancelling is still free.
    public static let freeWindow: TimeInterval = 120
    /// Flat fee charged after the free window. Display only; the backend is the source of truth.
    public static let lateFee = Money.bdt(20)

    /// Depends on the clock, so the same trip can go from free to paid while the sheet is open.
    /// `now` is a parameter so tests can control time.
    public static func quote(for trip: Trip, now: Date = Date()) -> CancellationQuote {
        switch trip.status {
        case .negotiating, .searchingDriver:
            return CancellationQuote(fee: .bdt(0), isFree: true, explanation: String(localized: "No driver has been matched yet — cancelling now is free."))
        case .driverAssigned, .driverArriving:
            guard let assignedAt = trip.driverAssignedAt else {
                return CancellationQuote(fee: .bdt(0), isFree: true, explanation: String(localized: "Cancelling now is free."))
            }
            let elapsed = now.timeIntervalSince(assignedAt)
            if elapsed <= freeWindow {
                let remaining = Int(freeWindow - elapsed)
                return CancellationQuote(fee: .bdt(0), isFree: true, explanation: String(localized: "Free for the next \(remaining)s."))
            } else {
                return CancellationQuote(
                    fee: lateFee,
                    isFree: false,
                    explanation: String(localized: "Your driver is already on the way, so a \(lateFee.formatted) cancellation fee applies.")
                )
            }
        case .inProgress, .completed, .cancelled:
            return CancellationQuote(fee: .bdt(0), isFree: true, explanation: String(localized: "This trip can no longer be cancelled."))
        }
    }
}
