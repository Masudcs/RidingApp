import SwiftUI

/// Bottom sheet with a tapped zone's name, demand level and trip estimate.
public struct DemandZoneDetailView: View {
    private let title: String
    private let intensity: DemandZone.Intensity
    private let demandText: String
    private let tripsText: String

    public init(title: String, intensity: DemandZone.Intensity, demandText: String, tripsText: String) {
        self.title = title
        self.intensity = intensity
        self.demandText = demandText
        self.tripsText = tripsText
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(BrandTypography.title)
            HStack(spacing: 6) {
                Circle()
                    .fill(intensity.color)
                    .frame(width: 12, height: 12)
                Text(demandText)
                    .font(BrandTypography.body)
            }
            Text(tripsText)
                .font(BrandTypography.body)
                .foregroundStyle(BrandColor.textSecondary)
            Spacer()
        }
        .padding()
        .presentationDetents([.fraction(0.25)])
    }
}

#if DEBUG

#Preview("High demand") {
    DemandZoneDetailView(title: "Gulshan 1", intensity: .high, demandText: "High demand", tripsText: "~48 trips/hour")
}

#Preview("Low demand") {
    DemandZoneDetailView(title: "Uttara", intensity: .low, demandText: "Low demand", tripsText: "~9 trips/hour")
}

#Preview("Long text") {
    DemandZoneDetailView(
        title: "Bashundhara Residential Area, Block D, Road 12, Dhaka",
        intensity: .medium,
        demandText: "Medium demand",
        tripsText: "~24 trips/hour"
    )
}

#endif
