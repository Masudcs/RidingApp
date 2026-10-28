import Foundation

/// Plays the role of the backend's business logic for driver earnings, reached over `APIClient`
/// instead of called directly — the computations are the same ones a real server would run, just
/// running in-process until a real backend exists.
/// An actor so concurrent requests are applied one at a time, like a server serializing balance updates.
/// State lives in memory only and resets on relaunch.
actor DriverEarningsBackend {
    private static let minimumCashOut = Money.bdt(50)
    private let logger = AppLogger(category: "DriverEarningsBackend")

    private var availableBalance: Money
    private var summary: DriverEarningsSummary
    private var history: [CashOutRequest] = []
    private var incentives: [DriverIncentive]
    /// First successful result per idempotency key; a replay returns it without moving money again.
    private var cashOutsByKey: [String: CashOutRequest] = [:]
    private var claimsByKey: [String: DriverIncentive] = [:]

    init() {
        let initialSummary = DriverEarningsSummary(
            availableBalance: .bdt(2_340),
            todayEarnings: .bdt(890),
            weekEarnings: .bdt(11_200),
            completedTripsToday: 14
        )
        self.summary = initialSummary
        self.availableBalance = initialSummary.availableBalance
        self.incentives = [
            DriverIncentive(
                title: "Daily Streak",
                description: "Complete 15 trips today for a bonus",
                targetTrips: 15,
                currentTrips: initialSummary.completedTripsToday,
                reward: .bdt(150),
                status: .inProgress
            ),
            DriverIncentive(
                title: "Morning Rush",
                description: "Complete 5 trips before noon",
                targetTrips: 5,
                currentTrips: 5,
                reward: .bdt(80),
                status: .completed
            ),
            DriverIncentive(
                title: "Weekly Champion",
                description: "Complete 80 trips this week",
                targetTrips: 80,
                currentTrips: 62,
                reward: .bdt(500),
                status: .inProgress
            )
        ]
    }

    func fetchSummary() -> DriverEarningsSummary {
        summary
    }

    func fetchCashOutHistory() -> [CashOutRequest] {
        history.sorted { $0.requestedAt > $1.requestedAt }
    }

    func fetchIncentives() -> [DriverIncentive] {
        incentives
    }

    /// Rejects below-minimum or above-balance amounts, then deducts and records the request as
    /// settled immediately (the mock has no processing delay).
    func requestCashOut(amount: Money, destination: PaymentMethodType, idempotencyKey: String? = nil) throws -> CashOutRequest {
        if let idempotencyKey, let first = cashOutsByKey[idempotencyKey] { return first }
        guard amount >= Self.minimumCashOut else {
            logger.error("Cash-out rejected: \(amount.formatted) is below minimum")
            throw CashOutError.belowMinimum
        }
        guard amount <= availableBalance else {
            logger.error("Cash-out rejected: \(amount.formatted) exceeds available balance")
            throw CashOutError.exceedsAvailableBalance
        }

        availableBalance = Money(minorUnits: availableBalance.minorUnits - amount.minorUnits, currencyCode: availableBalance.currencyCode)
        summary = DriverEarningsSummary(
            availableBalance: availableBalance,
            todayEarnings: summary.todayEarnings,
            weekEarnings: summary.weekEarnings,
            completedTripsToday: summary.completedTripsToday
        )

        let request = CashOutRequest(
            amount: amount,
            destination: destination,
            status: .settled,
            settledAt: Date()
        )
        history.append(request)
        if let idempotencyKey { cashOutsByKey[idempotencyKey] = request }
        logger.info("Cash-out settled instantly: \(amount.formatted) to \(destination.displayName)")
        return request
    }

    /// Credits the reward once; a second claim fails with `.notEligible` because status is `.claimed`.
    func claimIncentive(id: String, idempotencyKey: String? = nil) throws -> DriverIncentive {
        if let idempotencyKey, let first = claimsByKey[idempotencyKey] { return first }
        guard let index = incentives.firstIndex(where: { $0.id == id }) else {
            throw IncentiveError.notFound
        }
        guard incentives[index].status == .completed else {
            throw IncentiveError.notEligible
        }

        incentives[index].status = .claimed
        let reward = incentives[index].reward
        availableBalance = availableBalance + reward
        summary = DriverEarningsSummary(
            availableBalance: availableBalance,
            todayEarnings: summary.todayEarnings + reward,
            weekEarnings: summary.weekEarnings + reward,
            completedTripsToday: summary.completedTripsToday
        )
        logger.info("Claimed incentive '\(incentives[index].title)' for \(reward.formatted)")
        if let idempotencyKey { claimsByKey[idempotencyKey] = incentives[index] }
        return incentives[index]
    }

    /// Adds a referral bonus to the balance and this week's earnings (called from the profile flow).
    func creditReferralBonus(amount: Money) -> DriverEarningsSummary {
        availableBalance = availableBalance + amount
        summary = DriverEarningsSummary(
            availableBalance: availableBalance,
            todayEarnings: summary.todayEarnings,
            weekEarnings: summary.weekEarnings + amount,
            completedTripsToday: summary.completedTripsToday
        )
        logger.info("Credited referral bonus: \(amount.formatted)")
        return summary
    }
}
