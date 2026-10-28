import SwiftUI

/// Confirmation banner shown after an SOS was accepted by the backend; `statusText` is its current status.
struct SOSAlertBanner: View {
    let statusText: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.shield.fill")
            VStack(alignment: .leading, spacing: 2) {
                Text("Emergency services notified")
                    .font(BrandTypography.headline)
                Text(statusText)
                    .font(BrandTypography.caption)
            }
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(BrandColor.danger)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#if DEBUG

#Preview("Alert sent") {
    SOSAlertBanner(statusText: "Alert sent")
        .padding()
}

#Preview("Dispatcher notified") {
    SOSAlertBanner(statusText: "Dispatcher notified")
        .padding()
}

#endif
