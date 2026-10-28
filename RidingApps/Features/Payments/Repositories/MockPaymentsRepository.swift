import Foundation

/// In-memory stand-in for the payments backend, used when `usesMockServices` is on. Mimics the
/// real rules (wallet needs enough balance, other methods sometimes decline) so error paths can
/// be exercised. State is lost on relaunch.
public actor MockPaymentsRepository: IPaymentsRepository {
    private let logger = AppLogger(category: "Payments")

    private var savedMethods: [PaymentMethodAccount] = [
        PaymentMethodAccount(type: .bKash, maskedIdentifier: "•••• 8821", isDefault: true),
        PaymentMethodAccount(type: .card, maskedIdentifier: "•••• 4242")
    ]

    private var walletBalance: Money = .bdt(450)
    private var history: [PaymentReceipt] = []
    /// First result per idempotency key, so a retried action returns the same outcome without moving money again.
    private var chargesByKey: [String: PaymentReceipt] = [:]
    private var topUpsByKey: [String: Money] = [:]

    /// One in-memory "backend" shared by every screen so the wallet balance stays consistent
    /// between checkout and the wallet screen.
    public static let shared = MockPaymentsRepository()

    public init() {}

    public func fetchSavedMethods() async throws -> [PaymentMethodAccount] {
        await MockLatency.short()
        return savedMethods
    }

    public func fetchWalletBalance() async throws -> Money {
        await MockLatency.short()
        return walletBalance
    }

    /// Mirrors the server contract: payable = (amount - discount + tip) / splitCount, in minor units.
    public func charge(tripId: String, amount: Money, method: PaymentMethodType, promoCode: String?, discount: Money, tip: Money, splitCount: Int, idempotencyKey: String?) async throws -> PaymentReceipt {
        await MockLatency.short()
        if let idempotencyKey, let first = chargesByKey[idempotencyKey] { return first }

        let afterDiscount = max(0, amount.minorUnits - discount.minorUnits) + tip.minorUnits
        let safeSplitCount = max(1, splitCount)
        let payable = Money(minorUnits: afterDiscount / safeSplitCount, currencyCode: amount.currencyCode)

        if method == .wallet {
            guard walletBalance >= payable else {
                logger.error("Wallet charge declined: insufficient balance for trip \(tripId)")
                throw PaymentError.insufficientBalance
            }
        } else if method != .cash {
            if Double.random(in: 0..<1) < 0.1 {
                logger.error("Payment declined for trip \(tripId) via \(method.displayName)")
                throw PaymentError.declined
            }
        }

        if method == .wallet {
            walletBalance = Money(minorUnits: walletBalance.minorUnits - payable.minorUnits, currencyCode: walletBalance.currencyCode)
        }

        let receipt = PaymentReceipt(
            tripId: tripId,
            method: method,
            amount: payable,
            status: .captured,
            promoCode: promoCode,
            discountApplied: discount,
            tipAmount: tip,
            splitCount: safeSplitCount
        )
        history.append(receipt)
        if let idempotencyKey { chargesByKey[idempotencyKey] = receipt }
        logger.info("Charged \(payable.formatted) for trip \(tripId) via \(method.displayName)")
        return receipt
    }

    public func linkMethod(type: PaymentMethodType, identifier: String) async throws -> PaymentMethodAccount {
        await MockLatency.short()
        let account = PaymentMethodAccount(type: type, maskedIdentifier: identifier)
        savedMethods.append(account)
        logger.info("Linked new \(type.displayName) method")
        return account
    }

    public func paymentHistory() async throws -> [PaymentReceipt] {
        await MockLatency.short()
        return history
    }

    public func topUp(amount: Money, method: PaymentMethodType, idempotencyKey: String?) async throws -> Money {
        await MockLatency.short()
        if let idempotencyKey, let first = topUpsByKey[idempotencyKey] { return first }
        guard amount.minorUnits > 0 else { throw PaymentError.declined }

        if method != .cash {
            if Double.random(in: 0..<1) < 0.05 {
                logger.error("Wallet top-up declined via \(method.displayName)")
                throw PaymentError.declined
            }
        }

        walletBalance = walletBalance + amount
        if let idempotencyKey { topUpsByKey[idempotencyKey] = walletBalance }
        logger.info("Topped up wallet by \(amount.formatted) via \(method.displayName)")
        return walletBalance
    }
}
