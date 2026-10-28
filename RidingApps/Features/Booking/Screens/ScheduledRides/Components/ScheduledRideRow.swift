import SwiftUI

/// One scheduled ride with a "Start Now" button.
public struct ScheduledRideRow: View {
    private let systemImageName: String
    private let routeText: String
    private let fareText: String
    private let dateText: String
    private let isStarting: Bool
    private let onStartNow: () -> Void

    public init(systemImageName: String, routeText: String, fareText: String, dateText: String, isStarting: Bool = false, onStartNow: @escaping () -> Void) {
        self.systemImageName = systemImageName
        self.routeText = routeText
        self.fareText = fareText
        self.dateText = dateText
        self.isStarting = isStarting
        self.onStartNow = onStartNow
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImageName)
                    .foregroundStyle(BrandColor.primary)
                Text(routeText)
                    .font(BrandTypography.headline)
                Spacer()
                Text(fareText)
                    .font(BrandTypography.headline)
            }
            Text(dateText)
                .font(BrandTypography.caption)
                .foregroundStyle(BrandColor.textSecondary)
            SecondaryButton("Start Now", action: onStartNow)
                .disabled(isStarting)
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG

#Preview("Default") {
    List {
        ScheduledRideRow(
            systemImageName: VehicleType.car.systemImageName,
            routeText: "Gulshan 1 \u{2192} Dhanmondi 27",
            fareText: Money.bdt(220).formatted,
            dateText: "Tomorrow, 9:00 AM",
            onStartNow: {}
        )
    }
}

#Preview("Starting") {
    List {
        ScheduledRideRow(
            systemImageName: VehicleType.bike.systemImageName,
            routeText: "Gulshan 1 \u{2192} Dhanmondi 27",
            fareText: Money.bdt(90).formatted,
            dateText: "Tomorrow, 9:00 AM",
            isStarting: true,
            onStartNow: {}
        )
    }
}

#Preview("Long text") {
    List {
        ScheduledRideRow(
            systemImageName: VehicleType.premium.systemImageName,
            routeText: "Bangabandhu International Conference Center \u{2192} Hazrat Shahjalal International Airport",
            fareText: Money.bdt(1450).formatted,
            dateText: "Oct 28, 2026 at 4:45 AM",
            onStartNow: {}
        )
    }
}

#endif
