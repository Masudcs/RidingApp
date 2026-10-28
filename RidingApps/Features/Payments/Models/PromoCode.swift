import Foundation

/// A discount applied at checkout. `minimumFare` gates codes meant for longer trips (e.g. a flat
/// discount that wouldn't make sense on a ৳30 bike ride); `maxDiscount` caps percentage-off codes
/// so a huge fare doesn't turn a promo into a free ride.
public struct PromoCode: Equatable, Codable, Sendable {
    /// How the discount is worked out.
    public enum Kind: Equatable, Codable, Sendable {
        /// Fraction of the fare, e.g. 0.20 for 20% off.
        case percentage(Double)
        case flat(Money)
    }

    public let code: String
    public let kind: Kind
    public let description: String
    public let maxDiscount: Money?
    public let minimumFare: Money?

    public init(code: String, kind: Kind, description: String, maxDiscount: Money? = nil, minimumFare: Money? = nil) {
        self.code = code
        self.kind = kind
        self.description = description
        self.maxDiscount = maxDiscount
        self.minimumFare = minimumFare
    }

    /// Discount this code gives on `fareAmount`: percentage or flat amount, capped by `maxDiscount`,
    /// and never more than the fare itself. Does not check `minimumFare`; the repository does.
    public func discount(on fareAmount: Money) -> Money {
        let raw: Money
        switch kind {
        case .percentage(let fraction):
            raw = Money(minorUnits: Int((Double(fareAmount.minorUnits) * fraction).rounded()), currencyCode: fareAmount.currencyCode)
        case .flat(let amount):
            raw = amount
        }
        let capped = maxDiscount.map { min(raw, $0) } ?? raw
        return min(capped, fareAmount)
    }
}

/// Reasons a promo code can't be applied to a fare.
public enum PromoCodeError: Error, Sendable, Equatable {
    case notFound
    case belowMinimumFare(Money)
}

#if DEBUG

// Fixed fake data for SwiftUI previews. Debug builds only, so none of it ships.

public extension PromoCode {
    static func mock(
        code: String = "WELCOME20",
        kind: Kind = .percentage(0.20),
        description: String = "20% off your ride",
        maxDiscount: Money? = .bdt(50),
        minimumFare: Money? = nil
    ) -> PromoCode {
        PromoCode(code: code, kind: kind, description: description, maxDiscount: maxDiscount, minimumFare: minimumFare)
    }
}

#endif
