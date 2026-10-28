import SwiftUI

/// One past trip: route, counterpart, fare, status and date.
struct RideHistoryRow: View {
    let entry: RideHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: entry.vehicleType.systemImageName)
                    .foregroundStyle(BrandColor.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.pickupTitle) \u{2192} \(entry.dropoffTitle)")
                        .font(BrandTypography.headline)
                    Text(entry.role == .rider ? String(localized: "Driver: \(entry.counterpartName)") : String(localized: "Rider: \(entry.counterpartName)"))
                        .font(BrandTypography.caption)
                        .foregroundStyle(BrandColor.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(entry.fare.formatted)
                        .font(BrandTypography.headline)
                    RideStatusBadge(status: entry.status)
                }
            }
            Text(entry.completedAt, style: .date)
                .font(BrandTypography.caption)
                .foregroundStyle(BrandColor.textSecondary)
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG

#Preview("Rider, completed") {
    RideHistoryRow(entry: .mock())
        .padding()
}

#Preview("Rider, cancelled") {
    RideHistoryRow(entry: .mock(status: .cancelled, vehicleType: .bike))
        .padding()
}

#Preview("Driver entry") {
    RideHistoryRow(entry: .mock(role: .driver, vehicleType: .cng))
        .padding()
}

#Preview("Long text") {
    RideHistoryRow(entry: .mock(
        pickupTitle: "Bashundhara Residential Area, Block D, Road 12",
        dropoffTitle: "Hazrat Shahjalal International Airport, Terminal 1"
    ))
    .padding()
}

#endif
