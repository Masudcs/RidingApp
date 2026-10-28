import SwiftUI

/// Receipt summary shown in place of the pay controls once the charge succeeded.
struct PaymentSuccessCard: View {
    let receipt: PaymentReceipt

    var body: some View {
        SectionCard {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.largeTitle)
                    .foregroundStyle(BrandColor.success)
                Text("Payment Successful")
                    .font(BrandTypography.headline)
                Text("\(receipt.amount.formatted) via \(receipt.method.displayName)")
                    .font(BrandTypography.caption)
                    .foregroundStyle(BrandColor.textSecondary)
                if receipt.discountApplied.minorUnits > 0 {
                    Text("Promo \(receipt.promoCode ?? "") saved you \(receipt.discountApplied.formatted)")
                        .font(BrandTypography.caption)
                        .foregroundStyle(BrandColor.success)
                }
                if receipt.tipAmount.minorUnits > 0 {
                    Text("Includes \(receipt.tipAmount.formatted) tip")
                        .font(BrandTypography.caption)
                        .foregroundStyle(BrandColor.textSecondary)
                }
                if receipt.splitCount > 1 {
                    Text("Your share of a \(receipt.splitCount)-way split")
                        .font(BrandTypography.caption)
                        .foregroundStyle(BrandColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#if DEBUG

#Preview("Plain") {
    PaymentSuccessCard(receipt: .mock())
        .padding()
        .background(BrandColor.background)
}

#Preview("Promo, tip and split") {
    PaymentSuccessCard(receipt: PaymentReceipt(
        tripId: "trip-1",
        method: .wallet,
        amount: .bdt(120),
        status: .captured,
        promoCode: "WELCOME20",
        discountApplied: .bdt(44),
        tipAmount: .bdt(22),
        splitCount: 2
    ))
    .padding()
    .background(BrandColor.background)
}

#endif
