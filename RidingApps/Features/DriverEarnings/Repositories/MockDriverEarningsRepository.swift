import Foundation

/// Offline stand-in for the earnings API (used when `usesMockServices` is on).
/// Every call is a real `APIClient.send(_:)` request/response round trip against JSON-encoded
/// models — it forwards to `DriverEarningsRepository` over a `MockAPIClient` whose handlers run
/// `DriverEarningsBackend`'s business logic in-process, the same shape a `URLSessionAPIClient`
/// call against a real backend would have.
public final class MockDriverEarningsRepository: IDriverEarningsRepository, Sendable {
    /// Shared so the earnings dashboard, cash-out sheet and referral credits see the same balance.
    public static let shared = MockDriverEarningsRepository()

    private typealias Paths = DriverEarningsRepository.Paths
    private typealias CashOutBody = DriverEarningsRepository.CashOutBody
    private typealias ClaimBody = DriverEarningsRepository.ClaimBody
    private typealias ReferralBody = DriverEarningsRepository.ReferralBody

    private let repository: DriverEarningsRepository

    public init(apiClient: MockAPIClient = MockAPIClient()) {
        self.repository = DriverEarningsRepository(apiClient: apiClient)
        let backend = DriverEarningsBackend()

        apiClient.register(.get, Paths.summary) { _ in
            try JSONEncoder().encode(await backend.fetchSummary())
        }
        apiClient.register(.get, Paths.cashOuts) { _ in
            try JSONEncoder().encode(await backend.fetchCashOutHistory())
        }
        apiClient.register(.get, Paths.incentives) { _ in
            try JSONEncoder().encode(await backend.fetchIncentives())
        }
        apiClient.register(.post, Paths.cashOuts) { endpoint in
            guard let bodyData = endpoint.body else { throw NetworkError.decoding("Missing request body") }
            let body = try JSONDecoder().decode(CashOutBody.self, from: bodyData)
            let request = try await backend.requestCashOut(amount: body.amount, destination: body.destination, idempotencyKey: endpoint.idempotencyKey)
            return try JSONEncoder().encode(request)
        }
        apiClient.register(.post, Paths.claimIncentive) { endpoint in
            guard let bodyData = endpoint.body else { throw NetworkError.decoding("Missing request body") }
            let body = try JSONDecoder().decode(ClaimBody.self, from: bodyData)
            let incentive = try await backend.claimIncentive(id: body.id, idempotencyKey: endpoint.idempotencyKey)
            return try JSONEncoder().encode(incentive)
        }
        apiClient.register(.post, Paths.referralCredit) { endpoint in
            guard let bodyData = endpoint.body else { throw NetworkError.decoding("Missing request body") }
            let body = try JSONDecoder().decode(ReferralBody.self, from: bodyData)
            let summary = await backend.creditReferralBonus(amount: body.amount)
            return try JSONEncoder().encode(summary)
        }
    }

    public func fetchSummary() async throws -> DriverEarningsSummary {
        try await repository.fetchSummary()
    }

    public func fetchCashOutHistory() async throws -> [CashOutRequest] {
        try await repository.fetchCashOutHistory()
    }

    public func fetchIncentives() async throws -> [DriverIncentive] {
        try await repository.fetchIncentives()
    }

    public func requestCashOut(amount: Money, destination: PaymentMethodType, idempotencyKey: String?) async throws -> CashOutRequest {
        try await repository.requestCashOut(amount: amount, destination: destination, idempotencyKey: idempotencyKey)
    }

    public func claimIncentive(id: String, idempotencyKey: String?) async throws -> DriverIncentive {
        try await repository.claimIncentive(id: id, idempotencyKey: idempotencyKey)
    }

    public func creditReferralBonus(amount: Money) async throws -> DriverEarningsSummary {
        try await repository.creditReferralBonus(amount: amount)
    }
}
