import SwiftUI

/// Pill showing the driver's ETA text, floated over the map.
public struct ETABanner: View {
    private let etaText: String

    public init(etaText: String) {
        self.etaText = etaText
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.fill")
                .font(.title3)
            Text(etaText)
                .font(BrandTypography.title)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(BrandColor.primaryDark)
        .clipShape(Capsule())
        .shadow(radius: 6, y: 3)
    }
}

#if DEBUG

#Preview("Minutes away") {
    ETABanner(etaText: "4 min away")
        .padding()
}

#Preview("Arriving now") {
    ETABanner(etaText: "Arriving now")
        .padding()
}

#Preview("Locating driver") {
    ETABanner(etaText: "Locating driver...")
        .padding()
}

#endif
