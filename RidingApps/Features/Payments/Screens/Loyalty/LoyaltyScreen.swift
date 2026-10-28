import SwiftUI

/// Shows the rider's loyalty tier, progress to the next tier and the tier/perk list.
public struct LoyaltyScreen: View {
    @State private var viewModel: LoyaltyViewModel

    public init(store: LoyaltyStore, viewModel: LoyaltyViewModel? = nil) {
        _viewModel = State(wrappedValue: viewModel ?? LoyaltyViewModel(store: store))
    }

    public var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Text(viewModel.tier.displayName)
                        .font(BrandTypography.largeTitle)
                        .foregroundStyle(BrandColor.primary)
                    Text(viewModel.pointsText)
                        .font(BrandTypography.body)
                        .foregroundStyle(BrandColor.textSecondary)
                    if let total = viewModel.progressTotal, let nextTierText = viewModel.nextTierText {
                        ProgressView(value: Double(viewModel.points), total: total)
                            .tint(BrandColor.primary)
                        Text(nextTierText)
                            .font(BrandTypography.caption)
                            .foregroundStyle(BrandColor.textSecondary)
                    } else {
                        Text("You've reached the top tier!")
                            .font(BrandTypography.caption)
                            .foregroundStyle(BrandColor.success)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("Tiers & Perks") {
                ForEach(LoyaltyTier.allCases, id: \.rawValue) { tier in
                    LoyaltyTierRow(tier: tier, isCurrent: tier == viewModel.tier)
                }
            }
        }
        .navigationTitle("Loyalty")
    }
}

#if DEBUG

#Preview("New rider") {
    NavigationStack {
        LoyaltyScreen(store: .mock(), viewModel: LoyaltyViewModel(isEmptyView: true))
    }
}

#Preview("Silver") {
    NavigationStack {
        LoyaltyScreen(store: .mock(), viewModel: LoyaltyViewModel())
    }
}

#Preview("Top tier") {
    NavigationStack {
        LoyaltyScreen(store: .mock(), viewModel: LoyaltyViewModel(tier: .platinum))
    }
}

#endif
