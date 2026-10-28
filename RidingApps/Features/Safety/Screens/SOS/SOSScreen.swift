import SwiftUI

/// SOS button that floats over the active trip, with a confirmation dialog and a status banner.
/// `currentLocation` is read when the user confirms, so pass the latest trip location.
public struct SOSScreen: View {
    private let currentLocation: GeoPoint

    @State private var viewModel: SOSViewModel

    public init(tripId: String, currentUserRole: UserRole, currentLocation: GeoPoint, viewModel: SOSViewModel? = nil) {
        self.currentLocation = currentLocation
        _viewModel = State(wrappedValue: viewModel ?? SOSViewModel(tripId: tripId, role: currentUserRole))
    }

    public var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            if let alert = viewModel.activeAlert {
                SOSAlertBanner(statusText: viewModel.statusDescription(for: alert))
            } else if let errorMessage = viewModel.errorMessage {
                ErrorBanner(errorMessage)
            }

            SOSButton(isTriggering: viewModel.isTriggering, isDisabled: viewModel.isButtonDisabled) {
                viewModel.didTapSOS()
            }
        }
        .confirmationDialog(
            "Trigger emergency SOS?",
            isPresented: Binding(
                get: { viewModel.isConfirming },
                set: { newValue in if !newValue { viewModel.didCancelConfirmation() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Trigger SOS", role: .destructive) {
                viewModel.didConfirmTrigger(location: currentLocation)
            }
            Button("Cancel", role: .cancel) {
                viewModel.didCancelConfirmation()
            }
        } message: {
            Text("This will alert emergency dispatchers and your emergency contacts immediately.")
        }
    }
}

#if DEBUG

#Preview("Idle") {
    SOSScreen(tripId: "trip-1", currentUserRole: .rider, currentLocation: .mockPickup, viewModel: SOSViewModel())
        .padding()
}

#Preview("Triggering") {
    SOSScreen(tripId: "trip-1", currentUserRole: .rider, currentLocation: .mockPickup, viewModel: SOSViewModel(isLoading: true))
        .padding()
}

#Preview("Sent") {
    SOSScreen(tripId: "trip-1", currentUserRole: .rider, currentLocation: .mockPickup, viewModel: SOSViewModel(isSent: true))
        .padding()
}

#Preview("Error") {
    SOSScreen(tripId: "trip-1", currentUserRole: .rider, currentLocation: .mockPickup, viewModel: SOSViewModel(isError: true))
        .padding()
}

#Preview("Sent - Dark") {
    SOSScreen(tripId: "trip-1", currentUserRole: .rider, currentLocation: .mockPickup, viewModel: SOSViewModel(isSent: true))
        .padding()
        .background(BrandColor.background)
        .preferredColorScheme(.dark)
}

#endif
