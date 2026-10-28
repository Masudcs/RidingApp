import SwiftUI

/// Explains why the price is surging, listing the backend-provided reasons.
public struct SurgeExplanationSheet: View {
    private let title: String
    private let reasons: [String]

    public init(title: String, reasons: [String]) {
        self.title = title
        self.reasons = reasons
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(BrandColor.warning)
                Text(title)
                    .font(BrandTypography.title)
            }

            Text("We keep prices transparent. Here's why fares are higher in your area at the moment:")
                .font(BrandTypography.body)
                .foregroundStyle(BrandColor.textSecondary)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(reasons, id: \.self) { reason in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .padding(.top, 6)
                            .foregroundStyle(BrandColor.textSecondary)
                        Text(reason)
                            .font(BrandTypography.body)
                    }
                }
            }

            Spacer()
        }
        .padding(24)
    }
}

#if DEBUG

#Preview("Reasons") {
    SurgeExplanationSheet(
        title: "Price is 1.5x higher right now",
        reasons: ["High demand in your area", "Rain in your area", "Limited drivers nearby"]
    )
}

#Preview("Single reason") {
    SurgeExplanationSheet(title: "Price is 1.2x higher right now", reasons: ["Rush hour traffic"])
}

#Preview("Long text") {
    SurgeExplanationSheet(
        title: "Price is 2.0x higher right now because of unusually heavy demand",
        reasons: [
            "Demand is far higher than the number of available drivers in the Gulshan and Banani area right now",
            "Heavy rain is slowing every trip down across the city"
        ]
    )
}

#endif
