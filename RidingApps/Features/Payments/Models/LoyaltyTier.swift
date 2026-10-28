import Foundation

/// Rider loyalty levels, from `bronze` up. A rider's tier is the highest one whose
/// `pointsThreshold` their points reach.
public enum LoyaltyTier: Int, CaseIterable, Comparable, Sendable {
    case bronze = 0
    case silver = 1
    case gold = 2
    case platinum = 3

    public static func < (lhs: LoyaltyTier, rhs: LoyaltyTier) -> Bool { lhs.rawValue < rhs.rawValue }

    public var displayName: String {
        switch self {
        case .bronze: return String(localized: "Bronze")
        case .silver: return String(localized: "Silver")
        case .gold: return String(localized: "Gold")
        case .platinum: return String(localized: "Platinum")
        }
    }

    /// Minimum lifetime points needed to be in this tier.
    public var pointsThreshold: Int {
        switch self {
        case .bronze: return 0
        case .silver: return 200
        case .gold: return 500
        case .platinum: return 1000
        }
    }

    /// One-line benefit shown on the Loyalty screen. Descriptive only; nothing applies it to fares yet.
    public var perk: String {
        switch self {
        case .bronze: return String(localized: "Welcome bonus on your first ride")
        case .silver: return String(localized: "Priority driver matching")
        case .gold: return String(localized: "5% off every ride")
        case .platinum: return String(localized: "Free cancellation, always")
        }
    }

    /// The tier a rider with `points` is in.
    public static func tier(for points: Int) -> LoyaltyTier {
        allCases.reversed().first { points >= $0.pointsThreshold } ?? .bronze
    }

    /// The tier above this one, or nil at the top.
    public var next: LoyaltyTier? {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self), index + 1 < all.count else { return nil }
        return all[index + 1]
    }
}

#if DEBUG

// Fixed fake data for SwiftUI previews. Debug builds only, so none of it ships.

public extension LoyaltyTier {
    /// A points total that falls inside this tier.
    var mockPoints: Int {
        switch self {
        case .bronze: return 120
        case .silver: return 320
        case .gold: return 700
        case .platinum: return 1200
        }
    }
}

#endif
