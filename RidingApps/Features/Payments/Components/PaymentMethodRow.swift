import SwiftUI

/// One selectable payment method line (icon, name, detail). Shows a check when `isSelected`; the
/// parent handles taps. The Wallet tab uses it read-only, checkout uses it as a radio list.
public struct PaymentMethodRow: View {
    private let systemImageName: String
    private let title: String
    private let subtitle: String
    private let isSelected: Bool

    public init(systemImageName: String, title: String, subtitle: String, isSelected: Bool = false) {
        self.systemImageName = systemImageName
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImageName)
                .font(.title3)
                .foregroundStyle(BrandColor.primary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BrandTypography.headline)
                    .foregroundStyle(BrandColor.textPrimary)
                Text(subtitle)
                    .font(BrandTypography.caption)
                    .foregroundStyle(BrandColor.textSecondary)
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? BrandColor.primary : BrandColor.textSecondary.opacity(0.4))
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

#if DEBUG

#Preview("Unselected") {
    PaymentMethodRow(systemImageName: PaymentMethodType.bKash.systemImageName, title: "bKash", subtitle: "01XXXXXXX00")
        .padding()
}

#Preview("Selected") {
    PaymentMethodRow(systemImageName: PaymentMethodType.wallet.systemImageName, title: "In-App Wallet", subtitle: Money.bdt(500).formatted, isSelected: true)
        .padding()
}

#endif
