import Foundation

/// Local promo catalog for mock mode. Applies the same trim/uppercase and minimum-fare rules as
/// `PromoCodeRepository`.
public actor MockPromoCodeRepository: IPromoCodeRepository {
    private let catalog: [String: PromoCode] = [
        "WELCOME20": PromoCode(code: "WELCOME20", kind: .percentage(0.20), description: "20% off your ride", maxDiscount: .bdt(50)),
        "FLAT30": PromoCode(code: "FLAT30", kind: .flat(.bdt(30)), description: "৳30 off rides over ৳100", minimumFare: .bdt(100)),
        "RIDE10": PromoCode(code: "RIDE10", kind: .percentage(0.10), description: "10% off your ride", maxDiscount: .bdt(25))
    ]

    public init() {}

    public func validate(code: String, fareAmount: Money) async throws -> PromoCode {
        await MockLatency.short()
        guard let promo = catalog[code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()] else {
            throw PromoCodeError.notFound
        }
        if let minimumFare = promo.minimumFare, fareAmount < minimumFare {
            throw PromoCodeError.belowMinimumFare(minimumFare)
        }
        return promo
    }
}
