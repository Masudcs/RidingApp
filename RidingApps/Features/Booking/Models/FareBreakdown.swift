import Foundation

/// Pricing constants shared between the mock fare estimator and the itemized receipt breakdown,
/// so the two never drift apart.
public enum FarePricing {
    /// A flat surcharge per additional stop, on top of the total route distance fare.
    public static let perStopFee = Money.bdt(10)
}

/// Reconstructs the line items behind a trip's suggested fare, for receipt display. Negotiated
/// trips may have settled on a different `agreedFare` than this breakdown's `total` — that's
/// surfaced separately by the caller, not folded in here, since a haggled price isn't itemizable.
public struct FareBreakdown: Equatable, Sendable {
    /// Straight-line distance through pickup, stops and dropoff (not road distance).
    public let distanceKm: Double
    public let baseFare: Money
    public let distanceFare: Money
    public let stopsFee: Money
    public let subtotalBeforeSurge: Money
    /// Whatever the suggested fare adds on top of the itemized subtotal, never negative.
    public let surgeAmount: Money
    public let total: Money

    public static func compute(for trip: Trip) -> FareBreakdown {
        let waypoints = [trip.pickup] + trip.stops + [trip.dropoff]
        var totalMeters = 0.0
        for index in 0..<(waypoints.count - 1) {
            totalMeters += waypoints[index].point.distance(to: waypoints[index + 1].point)
        }
        let distanceKm = totalMeters / 1000

        let baseFare = trip.vehicleType.baseFare
        let distanceFare = trip.vehicleType.baseFarePerKm * distanceKm
        let stopsFee = FarePricing.perStopFee * Double(trip.stops.count)
        let subtotal = baseFare + distanceFare + stopsFee
        let surgeAmount = Money(
            minorUnits: max(0, trip.suggestedFare.minorUnits - subtotal.minorUnits),
            currencyCode: subtotal.currencyCode
        )

        return FareBreakdown(
            distanceKm: distanceKm,
            baseFare: baseFare,
            distanceFare: distanceFare,
            stopsFee: stopsFee,
            subtotalBeforeSurge: subtotal,
            surgeAmount: surgeAmount,
            total: trip.suggestedFare
        )
    }
}
