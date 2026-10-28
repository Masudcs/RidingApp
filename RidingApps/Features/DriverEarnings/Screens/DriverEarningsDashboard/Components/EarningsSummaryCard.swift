import SwiftUI

/// Card at the top of the dashboard: available balance, today's and this week's earnings, trips today.
public struct EarningsSummaryCard: View {
    private let summary: DriverEarningsSummary

    public init(summary: DriverEarningsSummary) {
        self.summary = summary
    }

    public var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Available Balance")
                        .font(BrandTypography.caption)
                        .foregroundStyle(BrandColor.textSecondary)
                    Text(summary.availableBalance.formatted)
                        .font(BrandTypography.largeTitle)
                        .foregroundStyle(BrandColor.textPrimary)
                }

                Divider()

                HStack {
                    breakdownItem(title: "Today", amount: summary.todayEarnings)
                    Spacer()
                    breakdownItem(title: "This Week", amount: summary.weekEarnings)
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Trips Today")
                            .font(BrandTypography.caption)
                            .foregroundStyle(BrandColor.textSecondary)
                        Text("\(summary.completedTripsToday)")
                            .font(BrandTypography.headline)
                            .foregroundStyle(BrandColor.textPrimary)
                    }
                }
            }
        }
    }

    private func breakdownItem(title: String, amount: Money) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(BrandTypography.caption)
                .foregroundStyle(BrandColor.textSecondary)
            Text(amount.formatted)
                .font(BrandTypography.headline)
                .foregroundStyle(BrandColor.textPrimary)
        }
    }
}

#if DEBUG

#Preview("Typical") {
    EarningsSummaryCard(summary: .mock())
        .padding()
}

#Preview("Zero") {
    EarningsSummaryCard(summary: .mock(availableBalance: 0, todayEarnings: 0, weekEarnings: 0, completedTripsToday: 0))
        .padding()
}

#Preview("Large amounts") {
    EarningsSummaryCard(summary: .mock(availableBalance: 1_250_000.50, todayEarnings: 98_500, weekEarnings: 643_210, completedTripsToday: 128))
        .padding()
}

#endif
