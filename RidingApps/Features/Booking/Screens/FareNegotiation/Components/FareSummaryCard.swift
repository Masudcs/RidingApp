import SwiftUI

/// Top card: suggested fare, insurance line, stops, and a surge explanation link when surging.
public struct FareSummaryCard: View {
    private let fareText: String
    private let insuranceText: String
    private let stopsText: String?
    private let surgeText: String?
    private let onTapSurge: () -> Void

    public init(
        fareText: String,
        insuranceText: String,
        stopsText: String? = nil,
        surgeText: String? = nil,
        onTapSurge: @escaping () -> Void
    ) {
        self.fareText = fareText
        self.insuranceText = insuranceText
        self.stopsText = stopsText
        self.surgeText = surgeText
        self.onTapSurge = onTapSurge
    }

    public var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Suggested fare")
                        .font(BrandTypography.headline)
                    Spacer()
                    Text(fareText)
                        .font(BrandTypography.title)
                        .foregroundStyle(BrandColor.primary)
                }

                Text(insuranceText)
                    .font(BrandTypography.caption)
                    .foregroundStyle(BrandColor.textSecondary)

                if let stopsText {
                    Text(stopsText)
                        .font(BrandTypography.caption)
                        .foregroundStyle(BrandColor.textSecondary)
                }

                if let surgeText {
                    Button(action: onTapSurge) {
                        Label(surgeText, systemImage: "info.circle")
                            .font(BrandTypography.caption)
                            .foregroundStyle(BrandColor.warning)
                    }
                }
            }
        }
    }
}

#if DEBUG

#Preview("Estimate") {
    FareSummaryCard(fareText: Money.bdt(200).formatted, insuranceText: "Includes \u{09F3} 3 micro-insurance", onTapSurge: {})
        .padding()
}

#Preview("Loading estimate") {
    FareSummaryCard(fareText: "--", insuranceText: "Includes \u{09F3} 3 micro-insurance", onTapSurge: {})
        .padding()
}

#Preview("Surge and stops") {
    FareSummaryCard(
        fareText: Money.bdt(300).formatted,
        insuranceText: "Includes \u{09F3} 3 micro-insurance",
        stopsText: "1 stop: Farmgate",
        surgeText: "1.5x surge \u{2014} why?",
        onTapSurge: {}
    )
    .padding()
}

#Preview("Long text") {
    FareSummaryCard(
        fareText: Money.bdt(1450).formatted,
        insuranceText: "Includes \u{09F3} 3 micro-insurance",
        stopsText: "3 stops: Bangabandhu International Conference Center, Hazrat Shahjalal International Airport, Farmgate",
        surgeText: "2.0x surge \u{2014} why?",
        onTapSurge: {}
    )
    .padding()
}

#endif
