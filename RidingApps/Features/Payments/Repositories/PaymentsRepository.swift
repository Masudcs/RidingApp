import Foundation

/// Everything the Wallet and checkout screens need from the payments backend.
public protocol IPaymentsRepository: Sendable {
    func fetchSavedMethods() async throws -> [PaymentMethodAccount]
    func fetchWalletBalance() async throws -> Money
    /// Throws `PaymentError` for known declines; anything else is a transport/server failure and
    /// does not prove the charge failed. `amount` is the full trip fare before discount/tip/split; the receipt's own `amount` ends
    /// up being just this rider's share of (amount - discount + tip) across `splitCount` payers.
    /// - Parameter idempotencyKey: one key per user action; the same key sent again must not charge twice
    ///   and returns the first result. Reuse it when retrying after a failure.
    func charge(tripId: String, amount: Money, method: PaymentMethodType, promoCode: String?, discount: Money, tip: Money, splitCount: Int, idempotencyKey: String?) async throws -> PaymentReceipt
    func linkMethod(type: PaymentMethodType, identifier: String) async throws -> PaymentMethodAccount
    func paymentHistory() async throws -> [PaymentReceipt]
    /// Adds money to the in-app wallet from another linked method; returns the new balance.
    /// - Parameter idempotencyKey: one key per top-up action; the same key twice tops up once.
    func topUp(amount: Money, method: PaymentMethodType, idempotencyKey: String?) async throws -> Money
}

public extension IPaymentsRepository {
    /// Charge without an idempotency key.
    func charge(tripId: String, amount: Money, method: PaymentMethodType, promoCode: String?, discount: Money, tip: Money, splitCount: Int) async throws -> PaymentReceipt {
        try await charge(tripId: tripId, amount: amount, method: method, promoCode: promoCode, discount: discount, tip: tip, splitCount: splitCount, idempotencyKey: nil)
    }

    /// Top-up without an idempotency key.
    func topUp(amount: Money, method: PaymentMethodType) async throws -> Money {
        try await topUp(amount: amount, method: method, idempotencyKey: nil)
    }

    /// Old call sites that charge without a tip/split still compile.
    func charge(tripId: String, amount: Money, method: PaymentMethodType, promoCode: String?, discount: Money) async throws -> PaymentReceipt {
        try await charge(tripId: tripId, amount: amount, method: method, promoCode: promoCode, discount: discount, tip: Money(minorUnits: 0), splitCount: 1)
    }

    /// Old call sites (e.g. tests) that charge without a promo code still compile.
    func charge(tripId: String, amount: Money, method: PaymentMethodType) async throws -> PaymentReceipt {
        try await charge(tripId: tripId, amount: amount, method: method, promoCode: nil, discount: Money(minorUnits: 0))
    }
}

/// Business outcomes of a charge or top-up, as opposed to network failures.
public enum PaymentError: Error, Sendable, Equatable {
    case insufficientBalance
    case declined
}

/// Backend-backed payments (`/payments/...`). HTTP 402 means not enough wallet balance, 403 means
/// the payment method declined.
public final class PaymentsRepository: IPaymentsRepository {
    /// Body for `POST /payments/charges`.
    private struct ChargeBody: Codable, Sendable {
        let tripId: String
        let amount: Money
        let method: PaymentMethodType
        let promoCode: String?
        let discount: Money
        let tip: Money
        let splitCount: Int
    }

    /// Body for `POST /payments/methods`.
    private struct LinkMethodBody: Codable, Sendable {
        let type: PaymentMethodType
        let identifier: String
    }

    /// Body for `POST /payments/wallet/top-ups`.
    private struct TopUpBody: Codable, Sendable {
        let amount: Money
        let method: PaymentMethodType
    }

    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    /// Picks the mock or the real repository the same way for every screen that needs one.
    public static func makeDefault() -> IPaymentsRepository {
        if AppEnvironment.current.usesMockServices {
            return MockPaymentsRepository.shared
        }
        return PaymentsRepository(apiClient: APIClientFactory.make())
    }

    public func fetchSavedMethods() async throws -> [PaymentMethodAccount] {
        try await apiClient.send(Endpoint(path: "/payments/methods"))
    }

    public func fetchWalletBalance() async throws -> Money {
        try await apiClient.send(Endpoint(path: "/payments/wallet/balance"))
    }

    /// Maps HTTP 402 to `.insufficientBalance` and 403 to `.declined`; other errors pass through.
    public func charge(tripId: String, amount: Money, method: PaymentMethodType, promoCode: String?, discount: Money, tip: Money, splitCount: Int, idempotencyKey: String?) async throws -> PaymentReceipt {
        let body = ChargeBody(tripId: tripId, amount: amount, method: method, promoCode: promoCode, discount: discount, tip: tip, splitCount: splitCount)
        do {
            return try await apiClient.send(Endpoint(path: "/payments/charges", method: .post, body: try JSONEncoder().encode(body), idempotencyKey: idempotencyKey))
        } catch NetworkError.server(statusCode: 402) {
            throw PaymentError.insufficientBalance
        } catch NetworkError.server(statusCode: 403) {
            throw PaymentError.declined
        }
    }

    public func linkMethod(type: PaymentMethodType, identifier: String) async throws -> PaymentMethodAccount {
        let body = LinkMethodBody(type: type, identifier: identifier)
        return try await apiClient.send(Endpoint(path: "/payments/methods", method: .post, body: try JSONEncoder().encode(body)))
    }

    public func paymentHistory() async throws -> [PaymentReceipt] {
        try await apiClient.send(Endpoint(path: "/payments/history"))
    }

    /// Maps HTTP 403 to `.declined`; other errors pass through.
    public func topUp(amount: Money, method: PaymentMethodType, idempotencyKey: String?) async throws -> Money {
        let body = TopUpBody(amount: amount, method: method)
        do {
            return try await apiClient.send(Endpoint(path: "/payments/wallet/top-ups", method: .post, body: try JSONEncoder().encode(body), idempotencyKey: idempotencyKey))
        } catch NetworkError.server(statusCode: 403) {
            throw PaymentError.declined
        }
    }
}
