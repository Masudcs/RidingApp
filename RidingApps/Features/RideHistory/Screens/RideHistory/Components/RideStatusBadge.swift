import SwiftUI

/// Green "Completed" / red "Cancelled" label; any non-cancelled status reads as completed.
struct RideStatusBadge: View {
    let status: TripStatus

    var body: some View {
        Text(status == .cancelled ? String(localized: "Cancelled") : String(localized: "Completed"))
            .font(BrandTypography.caption)
            .foregroundStyle(status == .cancelled ? BrandColor.danger : BrandColor.success)
    }
}

#if DEBUG

#Preview("Completed") {
    RideStatusBadge(status: .completed)
        .padding()
}

#Preview("Cancelled") {
    RideStatusBadge(status: .cancelled)
        .padding()
}

#endif
