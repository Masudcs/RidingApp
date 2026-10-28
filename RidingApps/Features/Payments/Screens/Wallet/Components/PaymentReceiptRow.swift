import SwiftUI

/// One line in the Wallet's recent payments list. Takes ready-made text so it has no formatting logic.
struct PaymentReceiptRow: View {
    let title: String
    let dateText: String
    let amountText: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BrandTypography.headline)
                Text(dateText)
                    .font(BrandTypography.caption)
                    .foregroundStyle(BrandColor.textSecondary)
            }
            Spacer()
            Text(amountText)
                .font(BrandTypography.headline)
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG

#Preview("Receipt") {
    PaymentReceiptRow(title: "bKash", dateText: "Oct 27, 2026 at 9:41 AM", amountText: Money.bdt(223).formatted)
        .padding()
}

#endif
