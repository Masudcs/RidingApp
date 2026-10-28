import Foundation

/// Real-API implementation of `IDriverEarningsRepository`; each method is one request through
/// `APIClient`. Also used by the mock repository, which only swaps the client.
/// Cash-out and claim requests carry an `Idempotency-Key` header.
/// TODO(real API): `CashOutError`/`IncentiveError` are only thrown by the mock backend today; map
/// the real server's error responses to them.
public final class DriverEarningsRepository: IDriverEarningsRepository {
    /// Endpoint paths, shared with the mock repository so both sides register the same routes.
    enum Paths {
        static let summary = "/driver/earnings/summary"
        static let cashOuts = "/driver/earnings/cashouts"
        static let incentives = "/driver/earnings/incentives"
        static let claimIncentive = "/driver/earnings/incentives/claim"
        static let referralCredit = "/driver/earnings/referral-credit"
    }

    /// Body for the cash-out request (`Paths.cashOuts`).
    struct CashOutBody: Codable, Sendable {
        let amount: Money
        let destination: PaymentMethodType
    }

    /// Body for claiming an incentive (`Paths.claimIncentive`).
    struct ClaimBody: Codable, Sendable {
        let id: String
    }

    /// Body for the referral credit (`Paths.referralCredit`).
    struct ReferralBody: Codable, Sendable {
        let amount: Money
    }

    private let apiClient: APIClient

    public init(apiClient: APIClient = APIClientFactory.make()) {
        self.apiClient = apiClient
    }

    public func fetchSummary() async throws -> DriverEarningsSummary {
        try await apiClient.send(Endpoint(path: Paths.summary))
    }

    public func fetchCashOutHistory() async throws -> [CashOutRequest] {
        try await apiClient.send(Endpoint(path: Paths.cashOuts))
    }

    public func fetchIncentives() async throws -> [DriverIncentive] {
        try await apiClient.send(Endpoint(path: Paths.incentives))
    }

    public func requestCashOut(amount: Money, destination: PaymentMethodType, idempotencyKey: String?) async throws -> CashOutRequest {
        let body = try JSONEncoder().encode(CashOutBody(amount: amount, destination: destination))
        return try await apiClient.send(Endpoint(path: Paths.cashOuts, method: .post, body: body, idempotencyKey: idempotencyKey))
    }

    public func claimIncentive(id: String, idempotencyKey: String?) async throws -> DriverIncentive {
        let body = try JSONEncoder().encode(ClaimBody(id: id))
        return try await apiClient.send(Endpoint(path: Paths.claimIncentive, method: .post, body: body, idempotencyKey: idempotencyKey))
    }

    public func creditReferralBonus(amount: Money) async throws -> DriverEarningsSummary {
        let body = try JSONEncoder().encode(ReferralBody(amount: amount))
        return try await apiClient.send(Endpoint(path: Paths.referralCredit, method: .post, body: body))
    }
}
