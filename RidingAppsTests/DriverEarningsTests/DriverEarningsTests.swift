import Testing
import Foundation
@testable import RidingApps

struct DriverEarningsTests {
    @Test func cashOutExceedingBalanceThrows() async throws {
        let service = MockDriverEarningsRepository()
        let summary = try await service.fetchSummary()
        let tooMuch = Money(minorUnits: summary.availableBalance.minorUnits + 100_00)

        await #expect(throws: CashOutError.exceedsAvailableBalance) {
            _ = try await service.requestCashOut(amount: tooMuch, destination: .bKash)
        }
    }

    @Test func cashOutBelowMinimumThrows() async throws {
        let service = MockDriverEarningsRepository()

        await #expect(throws: CashOutError.belowMinimum) {
            _ = try await service.requestCashOut(amount: .bdt(10), destination: .nagad)
        }
    }

    @Test func validCashOutReducesBalanceAndSettlesInstantly() async throws {
        let service = MockDriverEarningsRepository()
        let before = try await service.fetchSummary()

        let request = try await service.requestCashOut(amount: .bdt(500), destination: .rocket)

        #expect(request.status == .settled)
        #expect(request.settledAt != nil)
        #expect(request.amount == .bdt(500))

        let after = try await service.fetchSummary()
        #expect(after.availableBalance.minorUnits == before.availableBalance.minorUnits - Money.bdt(500).minorUnits)

        let history = try await service.fetchCashOutHistory()
        #expect(history.contains { $0.id == request.id && $0.status == .settled })
    }

    @Test func claimingACompletedIncentiveAddsRewardToBalance() async throws {
        let service = MockDriverEarningsRepository()
        let before = try await service.fetchSummary()
        let incentives = try await service.fetchIncentives()
        let completed = try #require(incentives.first { $0.status == .completed })

        let claimed = try await service.claimIncentive(id: completed.id)

        #expect(claimed.status == .claimed)
        let after = try await service.fetchSummary()
        #expect(after.availableBalance == before.availableBalance + completed.reward)
    }

    @Test func claimingAnInProgressIncentiveThrowsNotEligible() async throws {
        let service = MockDriverEarningsRepository()
        let incentives = try await service.fetchIncentives()
        let inProgress = try #require(incentives.first { $0.status == .inProgress })

        await #expect(throws: IncentiveError.notEligible) {
            _ = try await service.claimIncentive(id: inProgress.id)
        }
    }

    @Test func claimingAnUnknownIncentiveThrowsNotFound() async throws {
        let service = MockDriverEarningsRepository()
        await #expect(throws: IncentiveError.notFound) {
            _ = try await service.claimIncentive(id: "nonexistent")
        }
    }

    @MainActor @Test func cashOutAmountParsingAcceptsValidAmounts() {
        let us = Locale(identifier: "en_US")
        #expect(CashOutViewModel.parseAmount("500", locale: us) == .bdt(500))
        #expect(CashOutViewModel.parseAmount(" 1,250.50 ", locale: us) == Money(minorUnits: 125_050))
        // Decimal parsing: 0.29 must be exactly 29 paisa.
        #expect(CashOutViewModel.parseAmount("0.29", locale: us) == Money(minorUnits: 29))
    }

    @MainActor @Test func cashOutAmountParsingRejectsInvalidAmounts() {
        let us = Locale(identifier: "en_US")
        for text in ["", "   ", "abc", "0", "0.00", "-5", "NaN", "inf", "10.005", "1000000000"] {
            #expect(CashOutViewModel.parseAmount(text, locale: us) == nil, "expected nil for \"\(text)\"")
        }
    }
}

struct DriverEarningsIdempotencyTests {
    @Test func sameKeyCashesOutOnlyOnce() async throws {
        let service = MockDriverEarningsRepository()
        let before = try await service.fetchSummary()

        let first = try await service.requestCashOut(amount: .bdt(500), destination: .bKash, idempotencyKey: "cash-1")
        let second = try await service.requestCashOut(amount: .bdt(500), destination: .bKash, idempotencyKey: "cash-1")

        #expect(first == second)
        let after = try await service.fetchSummary()
        #expect(after.availableBalance.minorUnits == before.availableBalance.minorUnits - 500_00)
        let history = try await service.fetchCashOutHistory()
        #expect(history.count == 1)
    }

    @Test func sameKeyClaimsIncentiveOnlyOnce() async throws {
        let service = MockDriverEarningsRepository()
        let incentives = try await service.fetchIncentives()
        let completed = try #require(incentives.first(where: { $0.status == .completed }))
        let before = try await service.fetchSummary()

        let first = try await service.claimIncentive(id: completed.id, idempotencyKey: "claim-1")
        let replay = try await service.claimIncentive(id: completed.id, idempotencyKey: "claim-1")

        #expect(first == replay)
        let after = try await service.fetchSummary()
        #expect(after.availableBalance.minorUnits == before.availableBalance.minorUnits + completed.reward.minorUnits)
    }

    @MainActor
    @Test func cashOutViewModelReusesKeyAfterNetworkFailure() async throws {
        let repository = KeyRecordingEarningsRepository(failures: 1)
        let viewModel = CashOutViewModel(availableBalance: .bdt(1_000), repository: repository)

        viewModel.amountText = "100"
        viewModel.didTapCashOut()
        try await waitUntil { repository.keys.count == 1 && !viewModel.isCashingOut }
        #expect(viewModel.errorMessage != nil)

        viewModel.didTapCashOut()   // same action, retried
        try await waitUntil { repository.keys.count == 2 && !viewModel.isCashingOut }
        #expect(viewModel.lastCashOut != nil)

        viewModel.amountText = "100"
        viewModel.didTapCashOut()   // new action after success
        try await waitUntil { repository.keys.count == 3 && !viewModel.isCashingOut }

        let keys = repository.keys
        #expect(keys[0] != nil)
        #expect(keys[0] == keys[1])
        #expect(keys[2] != nil && keys[2] != keys[0])
    }
}

/// Earnings double that records idempotency keys and fails the first cash-outs with a timeout.
private final class KeyRecordingEarningsRepository: IDriverEarningsRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [String?] = []
    private var failuresLeft: Int

    init(failures: Int) { failuresLeft = failures }

    var keys: [String?] { lock.withLock { recorded } }

    func fetchSummary() async throws -> DriverEarningsSummary { throw NetworkError.server(statusCode: 404) }
    func fetchCashOutHistory() async throws -> [CashOutRequest] { [] }
    func fetchIncentives() async throws -> [DriverIncentive] { [] }
    func requestCashOut(amount: Money, destination: PaymentMethodType, idempotencyKey: String?) async throws -> CashOutRequest {
        let shouldFail: Bool = lock.withLock {
            recorded.append(idempotencyKey)
            defer { if failuresLeft > 0 { failuresLeft -= 1 } }
            return failuresLeft > 0
        }
        if shouldFail { throw NetworkError.transport("timeout") }
        return CashOutRequest(amount: amount, destination: destination, status: .settled, settledAt: Date())
    }
    func claimIncentive(id: String, idempotencyKey: String?) async throws -> DriverIncentive { throw IncentiveError.notFound }
    func creditReferralBonus(amount: Money) async throws -> DriverEarningsSummary { throw NetworkError.server(statusCode: 404) }
}
