import SwiftUI

/// Tappable colored dot for one zone on the map.
public struct DemandZoneMarker: View {
    private let intensity: DemandZone.Intensity
    private let onTap: () -> Void

    public init(intensity: DemandZone.Intensity, onTap: @escaping () -> Void) {
        self.intensity = intensity
        self.onTap = onTap
    }

    public var body: some View {
        Circle()
            .fill(intensity.color.opacity(0.35))
            .overlay(Circle().stroke(intensity.color, lineWidth: 2))
            .frame(width: intensity.markerSize, height: intensity.markerSize)
            .onTapGesture(perform: onTap)
    }
}

extension DemandZone.Intensity {
    var color: Color {
        switch self {
        case .low: return BrandColor.success
        case .medium: return BrandColor.warning
        case .high: return BrandColor.danger
        }
    }

    var markerSize: CGFloat {
        switch self {
        case .low: return 24
        case .medium: return 34
        case .high: return 44
        }
    }
}

#if DEBUG

#Preview("Low") {
    DemandZoneMarker(intensity: .low, onTap: {})
        .padding()
}

#Preview("Medium") {
    DemandZoneMarker(intensity: .medium, onTap: {})
        .padding()
}

#Preview("High") {
    DemandZoneMarker(intensity: .high, onTap: {})
        .padding()
}

#endif
