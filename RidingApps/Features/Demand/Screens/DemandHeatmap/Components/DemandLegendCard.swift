import SwiftUI

/// Color key (low/medium/high) for the heatmap markers.
public struct DemandLegendCard: View {
    public init() {}

    public var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("Demand")
                    .font(BrandTypography.caption)
                    .foregroundStyle(BrandColor.textSecondary)
                legendRow(color: BrandColor.success, label: String(localized: "Low"))
                legendRow(color: BrandColor.warning, label: String(localized: "Medium"))
                legendRow(color: BrandColor.danger, label: String(localized: "High"))
            }
        }
    }

    private func legendRow(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(BrandTypography.caption)
                .foregroundStyle(BrandColor.textPrimary)
        }
    }
}

#if DEBUG

#Preview("Legend") {
    DemandLegendCard()
        .padding()
}

#endif
