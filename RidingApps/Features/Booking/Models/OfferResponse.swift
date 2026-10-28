
/// A driver's answer to the rider's latest offer.
public enum OfferResponse: Sendable {
    case accept
    case counter(Money)
    case decline
}

/// Booking errors the app raises itself (as opposed to transport errors from `APIClient`).
public enum BookingError: Error, Sendable {
    case tripNotFound
}

/// Core only exposes `+` on `Money`; fare estimation needs to scale a per-km rate by a distance,
/// so this multiply helper lives here rather than being added to Core.
func * (money: Money, factor: Double) -> Money {
    Money(minorUnits: Int((Double(money.minorUnits) * factor).rounded()), currencyCode: money.currencyCode)
}
