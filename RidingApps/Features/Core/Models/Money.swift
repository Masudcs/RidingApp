import Foundation

/// A monetary amount in minor units (paisa) to avoid floating point rounding errors in fares.
public struct Money: Equatable, Hashable, Codable, Sendable, Comparable {
    public let minorUnits: Int
    public let currencyCode: String

    public init(minorUnits: Int, currencyCode: String = "BDT") {
        self.minorUnits = minorUnits
        self.currencyCode = currencyCode
    }

    /// Convenience for whole/fractional taka, rounded to the nearest paisa.
    public static func bdt(_ taka: Double) -> Money {
        Money(minorUnits: Int((taka * 100).rounded()), currencyCode: "BDT")
    }

    /// For display only; don't do arithmetic on this.
    public var majorUnits: Double {
        Double(minorUnits) / 100.0
    }

    /// Localized currency string; BDT uses the \u{09F3} symbol. Creates a formatter per call.
    public var formatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.currencySymbol = currencyCode == "BDT" ? "\u{09F3} " : nil
        return formatter.string(from: NSNumber(value: majorUnits)) ?? "\(majorUnits)"
    }

    public static func < (lhs: Money, rhs: Money) -> Bool {
        lhs.minorUnits < rhs.minorUnits
    }

    /// Keeps the left side's currency and does not check that both match; callers only mix BDT today.
    public static func + (lhs: Money, rhs: Money) -> Money {
        Money(minorUnits: lhs.minorUnits + rhs.minorUnits, currencyCode: lhs.currencyCode)
    }
}
