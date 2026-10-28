import Testing
@testable import RidingApps
import Foundation

@Test func walletChargeExceedingBalanceThrowsInsufficientBalance() async throws {
    let service = MockPaymentsRepository()
    let balance = try await service.fetchWalletBalance()
    let tooMuch = Money(minorUnits: balance.minorUnits + 100_00, currencyCode: balance.currencyCode)

    await #expect(throws: PaymentError.insufficientBalance) {
        _ = try await service.charge(tripId: "trip-1", amount: tooMuch, method: .wallet)
    }
}

@Test func cashChargeSucceedsAndAppearsInHistory() async throws {
    let service = MockPaymentsRepository()
    let amount = Money.bdt(120)

    let receipt = try await service.charge(tripId: "trip-2", amount: amount, method: .cash)

    #expect(receipt.status == .captured)
    #expect(receipt.tripId == "trip-2")

    let history = try await service.paymentHistory()
    #expect(history.contains(where: { $0.id == receipt.id }))
}

@Test func linkMethodAddsToSavedMethods() async throws {
    let service = MockPaymentsRepository()
    let before = try await service.fetchSavedMethods()

    let account = try await service.linkMethod(type: .nagad, identifier: "•••• 9911")

    let after = try await service.fetchSavedMethods()
    #expect(after.count == before.count + 1)
    #expect(after.contains(where: { $0.id == account.id }))
}

@Test func percentagePromoCodeIsCappedByMaxDiscount() throws {
    let promo = PromoCode(code: "WELCOME20", kind: .percentage(0.20), description: "20% off", maxDiscount: .bdt(50))
    #expect(promo.discount(on: .bdt(1000)) == .bdt(50))
    #expect(promo.discount(on: .bdt(100)) == .bdt(20))
}

@Test func flatPromoCodeNeverExceedsTheFare() throws {
    let promo = PromoCode(code: "FLAT30", kind: .flat(.bdt(30)), description: "৳30 off")
    #expect(promo.discount(on: .bdt(20)) == .bdt(20))
    #expect(promo.discount(on: .bdt(100)) == .bdt(30))
}

@Test func validatingAnUnknownPromoCodeThrowsNotFound() async throws {
    let service = MockPromoCodeRepository()
    await #expect(throws: PromoCodeError.notFound) {
        _ = try await service.validate(code: "NOPE", fareAmount: .bdt(100))
    }
}

@Test func promoCodeBelowMinimumFareThrows() async throws {
    let service = MockPromoCodeRepository()
    await #expect(throws: PromoCodeError.belowMinimumFare(.bdt(100))) {
        _ = try await service.validate(code: "FLAT30", fareAmount: .bdt(50))
    }
}

@Test func chargeAppliesDiscountToPayableAmount() async throws {
    let service = MockPaymentsRepository()
    let receipt = try await service.charge(tripId: "trip-3", amount: .bdt(100), method: .cash, promoCode: "RIDE10", discount: .bdt(10))
    #expect(receipt.amount == .bdt(90))
    #expect(receipt.discountApplied == .bdt(10))
    #expect(receipt.promoCode == "RIDE10")
}

@Test func topUpIncreasesWalletBalance() async throws {
    let service = MockPaymentsRepository()
    let before = try await service.fetchWalletBalance()

    let after = try await service.topUp(amount: .bdt(200), method: .cash)

    #expect(after == before + .bdt(200))
    let confirmed = try await service.fetchWalletBalance()
    #expect(confirmed == after)
}

@Test func topUpWithNonPositiveAmountThrows() async throws {
    let service = MockPaymentsRepository()
    await #expect(throws: PaymentError.declined) {
        _ = try await service.topUp(amount: .bdt(0), method: .cash)
    }
}

@Test func chargeAddsTipBeforeSplitting() async throws {
    let service = MockPaymentsRepository()
    let receipt = try await service.charge(
        tripId: "trip-4",
        amount: .bdt(100),
        method: .cash,
        promoCode: nil,
        discount: .bdt(0),
        tip: .bdt(20),
        splitCount: 1
    )
    #expect(receipt.amount == .bdt(120))
    #expect(receipt.tipAmount == .bdt(20))
}

@Test func chargeSplitsFareEvenlyAcrossPayers() async throws {
    let service = MockPaymentsRepository()
    let receipt = try await service.charge(
        tripId: "trip-5",
        amount: .bdt(100),
        method: .cash,
        promoCode: nil,
        discount: .bdt(0),
        tip: .bdt(0),
        splitCount: 4
    )
    #expect(receipt.amount == .bdt(25))
    #expect(receipt.splitCount == 4)
}

@Test func loyaltyTierIsComputedFromPoints() throws {
    #expect(LoyaltyTier.tier(for: 0) == .bronze)
    #expect(LoyaltyTier.tier(for: 199) == .bronze)
    #expect(LoyaltyTier.tier(for: 200) == .silver)
    #expect(LoyaltyTier.tier(for: 500) == .gold)
    #expect(LoyaltyTier.tier(for: 1000) == .platinum)
}

@MainActor
@Test func loyaltyStoreAwardsAtLeastFivePointsPerRide() throws {
    let suiteName = "test.loyalty.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = LoyaltyStore(defaults: defaults)
    store.awardPoints(for: .bdt(20))
    #expect(store.points == 5)
    store.awardPoints(for: .bdt(100))
    #expect(store.points == 15)
}

@MainActor
@Test func referralRedeemRejectsOwnCodeAndDuplicates() throws {
    let suiteName = "test.referral.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = ReferralStore(userId: "rider-abc123", defaults: defaults)

    #expect(throws: ReferralStore.RedeemError.ownCode) {
        try store.redeem(store.myCode)
    }

    let bonus = try store.redeem("FRIEND1")
    #expect(bonus == ReferralStore.referralBonus)
    #expect(store.creditEarned == ReferralStore.referralBonus)

    #expect(throws: ReferralStore.RedeemError.alreadyRedeemed) {
        try store.redeem("friend1")
    }
}

@Test func sameIdempotencyKeyChargesWalletOnlyOnce() async throws {
    let service = MockPaymentsRepository()
    let before = try await service.fetchWalletBalance()

    let first = try await service.charge(tripId: "trip-k", amount: .bdt(100), method: .wallet, promoCode: nil, discount: Money(minorUnits: 0), tip: Money(minorUnits: 0), splitCount: 1, idempotencyKey: "key-1")
    let second = try await service.charge(tripId: "trip-k", amount: .bdt(100), method: .wallet, promoCode: nil, discount: Money(minorUnits: 0), tip: Money(minorUnits: 0), splitCount: 1, idempotencyKey: "key-1")

    #expect(first == second)
    let after = try await service.fetchWalletBalance()
    #expect(after.minorUnits == before.minorUnits - 100_00)
    let history = try await service.paymentHistory()
    #expect(history.filter { $0.tripId == "trip-k" }.count == 1)

    // A new action (new key) charges again.
    _ = try await service.charge(tripId: "trip-k", amount: .bdt(100), method: .wallet, promoCode: nil, discount: Money(minorUnits: 0), tip: Money(minorUnits: 0), splitCount: 1, idempotencyKey: "key-2")
    let final = try await service.fetchWalletBalance()
    #expect(final.minorUnits == before.minorUnits - 200_00)
}

@Test func sameIdempotencyKeyToppsUpOnlyOnce() async throws {
    let service = MockPaymentsRepository()
    let before = try await service.fetchWalletBalance()

    let first = try await service.topUp(amount: .bdt(200), method: .cash, idempotencyKey: "top-1")
    let second = try await service.topUp(amount: .bdt(200), method: .cash, idempotencyKey: "top-1")

    #expect(first == second)
    #expect(first.minorUnits == before.minorUnits + 200_00)
    let after = try await service.fetchWalletBalance()
    #expect(after == first)

    // Without a key every call is a new top-up.
    let third = try await service.topUp(amount: .bdt(200), method: .cash)
    #expect(third.minorUnits == first.minorUnits + 200_00)
}

/// Payments double that records the idempotency keys it receives and fails the first top-up.
private final class KeyRecordingPaymentsRepository: IPaymentsRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [String?] = []
    private var failuresLeft: Int

    init(failures: Int) { failuresLeft = failures }

    var keys: [String?] { lock.withLock { recorded } }

    func fetchSavedMethods() async throws -> [PaymentMethodAccount] { [] }
    func fetchWalletBalance() async throws -> Money { .bdt(0) }
    func charge(tripId: String, amount: Money, method: PaymentMethodType, promoCode: String?, discount: Money, tip: Money, splitCount: Int, idempotencyKey: String?) async throws -> PaymentReceipt {
        throw NetworkError.server(statusCode: 500)
    }
    func linkMethod(type: PaymentMethodType, identifier: String) async throws -> PaymentMethodAccount {
        throw NetworkError.server(statusCode: 500)
    }
    func paymentHistory() async throws -> [PaymentReceipt] { [] }
    func topUp(amount: Money, method: PaymentMethodType, idempotencyKey: String?) async throws -> Money {
        let shouldFail: Bool = lock.withLock {
            recorded.append(idempotencyKey)
            defer { if failuresLeft > 0 { failuresLeft -= 1 } }
            return failuresLeft > 0
        }
        if shouldFail { throw NetworkError.transport("timeout") }
        return amount
    }
}

@MainActor
@Test func walletReusesTopUpKeyAfterFailureAndDropsItAfterSuccess() async throws {
    let repository = KeyRecordingPaymentsRepository(failures: 1)
    let viewModel = WalletViewModel(repository: repository)

    viewModel.topUpAmountInput = "100"
    await viewModel.didTapTopUp()   // times out
    await viewModel.didTapTopUp()   // retry of the same action succeeds
    viewModel.topUpAmountInput = "100"
    await viewModel.didTapTopUp()   // a new action

    let keys = repository.keys
    #expect(keys.count == 3)
    #expect(keys[0] != nil)
    #expect(keys[0] == keys[1])
    #expect(keys[2] != nil && keys[2] != keys[0])
}
