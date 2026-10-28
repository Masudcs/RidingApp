import Combine
import Foundation
import Observation

/// Backs `LoyaltyScreen`: the current points, tier and progress toward the next tier, kept in sync with `LoyaltyStore`.
@MainActor
@Observable
public final class LoyaltyViewModel {
    /// Mirrors `LoyaltyStore.points`, so points earned at checkout show up live.
    public private(set) var points: Int
    @ObservationIgnored private var cancellable: AnyCancellable?

    public init(store: LoyaltyStore) {
        self.points = store.points
        cancellable = store.$points.sink { [weak self] in self?.points = $0 }
    }

    public var tier: LoyaltyTier { LoyaltyTier.tier(for: points) }

    public var pointsText: String { "\(points) points" }

    /// Points needed for the next tier (the progress bar's total), or nil at the top tier.
    public var progressTotal: Double? {
        tier.next.map { Double($0.pointsThreshold) }
    }

    public var nextTierText: String? {
        tier.next.map { "\(max(0, $0.pointsThreshold - points)) points to \($0.displayName)" }
    }
}

#if DEBUG

extension LoyaltyViewModel {
    /// Preview-only: fixed points for `tier`; `isEmptyView` is a brand-new rider with no points.
    /// There is nothing to load, so there is no loading or error look.
    convenience init(isPreview: Bool = true, isEmptyView: Bool = false, tier: LoyaltyTier = .silver) {
        self.init(store: .mock())
        points = isEmptyView ? 0 : tier.mockPoints
    }
}

#endif
