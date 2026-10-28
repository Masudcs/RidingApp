import SwiftUI

/// A tier name and perk in the Loyalty list; `isCurrent` marks the rider's tier with a check.
struct LoyaltyTierRow: View {
    let tier: LoyaltyTier
    let isCurrent: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(tier.displayName)
                    .font(BrandTypography.headline)
                Text(tier.perk)
                    .font(BrandTypography.caption)
                    .foregroundStyle(BrandColor.textSecondary)
            }
            Spacer()
            if isCurrent {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(BrandColor.primary)
            }
        }
    }
}

#if DEBUG

#Preview("Current tier") {
    LoyaltyTierRow(tier: .silver, isCurrent: true)
        .padding()
}

#Preview("Other tier") {
    LoyaltyTierRow(tier: .gold, isCurrent: false)
        .padding()
}

#endif
