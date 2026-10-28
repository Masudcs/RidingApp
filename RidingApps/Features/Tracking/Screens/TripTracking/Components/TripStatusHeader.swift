import SwiftUI

/// Card with trip status and driver details. The favorite/block buttons only show when the
/// matching closure is non-nil (riders only).
public struct TripStatusHeader: View {
    private let statusText: String
    private let vehicleType: VehicleType
    private let driverInfo: TripDriverInfo?
    private let isFavorite: Bool
    private let isBlocked: Bool
    private let onToggleFavorite: (() -> Void)?
    private let onToggleBlocked: (() -> Void)?

    public init(
        statusText: String,
        vehicleType: VehicleType,
        driverInfo: TripDriverInfo?,
        isFavorite: Bool = false,
        isBlocked: Bool = false,
        onToggleFavorite: (() -> Void)? = nil,
        onToggleBlocked: (() -> Void)? = nil
    ) {
        self.statusText = statusText
        self.vehicleType = vehicleType
        self.driverInfo = driverInfo
        self.isFavorite = isFavorite
        self.isBlocked = isBlocked
        self.onToggleFavorite = onToggleFavorite
        self.onToggleBlocked = onToggleBlocked
    }

    public var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: vehicleType.systemImageName)
                        .foregroundStyle(BrandColor.primary)
                    Text(statusText)
                        .font(BrandTypography.headline)
                        .foregroundStyle(BrandColor.textPrimary)
                }

                if let driverInfo {
                    HStack(spacing: 6) {
                        Text(driverInfo.name)
                            .font(BrandTypography.body)
                            .foregroundStyle(BrandColor.textPrimary)
                        Image(systemName: "star.fill")
                            .foregroundStyle(BrandColor.accent)
                            .font(.caption)
                        Text(String(format: "%.1f", driverInfo.ratingAverage))
                            .font(BrandTypography.caption)
                            .foregroundStyle(BrandColor.textSecondary)
                        Spacer()
                        Text(driverInfo.vehiclePlate)
                            .font(BrandTypography.caption)
                            .foregroundStyle(BrandColor.textSecondary)
                        if let onToggleFavorite {
                            Button(action: onToggleFavorite) {
                                Image(systemName: isFavorite ? "star.fill" : "star")
                                    .foregroundStyle(BrandColor.accent)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(isFavorite ? "Remove driver from favorites" : "Add driver to favorites")
                        }
                        if let onToggleBlocked {
                            Button(action: onToggleBlocked) {
                                Image(systemName: isBlocked ? "hand.raised.fill" : "hand.raised")
                                    .foregroundStyle(BrandColor.danger)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(isBlocked ? "Unblock driver" : "Block driver")
                        }
                    }
                } else {
                    Text("Looking for your driver's live location...")
                        .font(BrandTypography.caption)
                        .foregroundStyle(BrandColor.textSecondary)
                }
            }
        }
    }
}

#if DEBUG

#Preview("Driver assigned") {
    TripStatusHeader(
        statusText: "Driver assigned",
        vehicleType: .car,
        driverInfo: .mock(),
        onToggleFavorite: {},
        onToggleBlocked: {}
    )
    .padding()
}

#Preview("Searching for driver") {
    TripStatusHeader(statusText: "Searching for a driver", vehicleType: .car, driverInfo: nil)
        .padding()
}

#Preview("Favorite driver") {
    TripStatusHeader(
        statusText: "Driver is arriving",
        vehicleType: .bike,
        driverInfo: .mock(vehicleType: .bike),
        isFavorite: true,
        onToggleFavorite: {},
        onToggleBlocked: {}
    )
    .padding()
}

#Preview("Blocked driver") {
    TripStatusHeader(
        statusText: "Driver is arriving",
        vehicleType: .car,
        driverInfo: .mock(),
        isBlocked: true,
        onToggleFavorite: {},
        onToggleBlocked: {}
    )
    .padding()
}

#Preview("Driver view (no buttons)") {
    TripStatusHeader(statusText: "Trip in progress", vehicleType: .car, driverInfo: .mock())
        .padding()
}

#Preview("Long text") {
    TripStatusHeader(
        statusText: "Driver is arriving at the pickup point near the main entrance",
        vehicleType: .premium,
        driverInfo: .mock(name: "Mohammad Abdur Rahman Chowdhury Al-Mamun", vehicleType: .premium),
        onToggleFavorite: {},
        onToggleBlocked: {}
    )
    .padding()
}

#endif
