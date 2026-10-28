import Foundation

/// Looks up a promo code. It only checks that the code exists and the fare qualifies; the
/// discount amount is computed by `PromoCode.discount(on:)`.
public protocol IPromoCodeRepository: Sendable {
    /// Throws `PromoCodeError.notFound` or `.belowMinimumFare`; other errors are transport failures.
    func validate(code: String, fareAmount: Money) async throws -> PromoCode
}

/// Backend-backed promo lookup (`GET /promo-codes/{code}`).
public final class PromoCodeRepository: IPromoCodeRepository {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    /// Picks the mock or the real repository the same way for every screen that needs one.
    public static func makeDefault() -> IPromoCodeRepository {
        if AppEnvironment.current.usesMockServices {
            return MockPromoCodeRepository()
        }
        return PromoCodeRepository(apiClient: APIClientFactory.make())
    }

    public func validate(code: String, fareAmount: Money) async throws -> PromoCode {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        // Keep user text out of the URL path unless it is plain letters/digits/dash/underscore.
        guard !normalized.isEmpty,
              normalized.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }) else {
            throw PromoCodeError.notFound
        }
        let promo: PromoCode
        do {
            promo = try await apiClient.send(Endpoint(path: "/promo-codes/\(normalized)"))
        } catch NetworkError.server(statusCode: 404) {
            throw PromoCodeError.notFound
        }
        if let minimumFare = promo.minimumFare, fareAmount < minimumFare {
            throw PromoCodeError.belowMinimumFare(minimumFare)
        }
        return promo
    }
}

