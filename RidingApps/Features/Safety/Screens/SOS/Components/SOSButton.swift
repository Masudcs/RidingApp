import SwiftUI

/// Round red button for the SOS overlay. Shows a spinner while the request is in flight.
struct SOSButton: View {
    let isTriggering: Bool
    let isDisabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Group {
                if isTriggering {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                }
            }
            .frame(width: 60, height: 60)
            .foregroundStyle(.white)
            .background(BrandColor.danger)
            .clipShape(Circle())
            .shadow(color: BrandColor.danger.opacity(0.4), radius: 8, y: 4)
        }
        .disabled(isDisabled)
        .accessibilityLabel("Trigger emergency SOS")
    }
}

#if DEBUG

#Preview("Idle") {
    SOSButton(isTriggering: false, isDisabled: false) {}
        .padding()
}

#Preview("Triggering") {
    SOSButton(isTriggering: true, isDisabled: true) {}
        .padding()
}

#Preview("Disabled") {
    SOSButton(isTriggering: false, isDisabled: true) {}
        .padding()
}

#endif
