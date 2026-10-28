import Foundation

/// Data access for the driver Earnings tab. Implemented by `DriverEarningsRepository` (real API) and
/// `MockDriverEarningsRepository` (in-process fake backend). The server owns all balances; callers
/// should re-fetch the summary after any call that moves money.
public protocol IDriverEarningsRepository: Sendable {
    /// Balance, today's and this week's earnings.
    func fetchSummary() async throws -> DriverEarningsSummary
    func fetchCashOutHistory() async throws -> [CashOutRequest]
    /// Withdraws `amount` to `destination`. Moves money. Throws `CashOutError` for rule violations;
    /// other errors (network) mean the outcome is unknown, so retry with the SAME `idempotencyKey`
    /// (one key per user action): the server then returns the first result instead of paying twice.
    func requestCashOut(amount: Money, destination: PaymentMethodType, idempotencyKey: String?) async throws -> CashOutRequest
    func fetchIncentives() async throws -> [DriverIncentive]
    /// Adds the incentive's reward to the driver's balance; only valid once `status == .completed`.
    /// Pass the same `idempotencyKey` when retrying a claim whose outcome is unknown.
    func claimIncentive(id: String, idempotencyKey: String?) async throws -> DriverIncentive
    /// Adds a referral bonus straight to the driver's available balance, the same way a cleared
    /// incentive reward does.
    func creditReferralBonus(amount: Money) async throws -> DriverEarningsSummary
}

public extension IDriverEarningsRepository {
    /// Cash-out without an idempotency key.
    func requestCashOut(amount: Money, destination: PaymentMethodType) async throws -> CashOutRequest {
        try await requestCashOut(amount: amount, destination: destination, idempotencyKey: nil)
    }

    /// Claim without an idempotency key.
    func claimIncentive(id: String) async throws -> DriverIncentive {
        try await claimIncentive(id: id, idempotencyKey: nil)
    }
}

/// Cash-out rules the server enforces.
public enum CashOutError: Error, Sendable {
    case exceedsAvailableBalance
    case belowMinimum
}
