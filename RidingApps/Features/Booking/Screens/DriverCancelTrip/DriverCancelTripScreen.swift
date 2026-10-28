import SwiftUI

/// Driver-side counterpart of `CancellationScreen`; no fee, but the cancel counts against the driver.
public struct DriverCancelTripScreen: View {
    @State private var viewModel: DriverCancelTripViewModel

    public init(onConfirm: @escaping (DriverCancellationReason) -> Void, onKeepTrip: @escaping () -> Void) {
        _viewModel = State(wrappedValue: DriverCancelTripViewModel(onConfirm: onConfirm, onKeepTrip: onKeepTrip))
    }

    public var body: some View {
        @Bindable var viewModel = viewModel
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 44))
                    .foregroundStyle(BrandColor.warning)
                Text("Cancel this trip?")
                    .font(BrandTypography.title)
                Text("This will be recorded against your cancellation rate.")
                    .font(BrandTypography.body)
                    .foregroundStyle(BrandColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Picker("Reason", selection: $viewModel.selectedReason) {
                ForEach(DriverCancellationReason.allCases) { reason in
                    Text(reason.displayName).tag(reason)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxHeight: 140)

            VStack(spacing: 12) {
                SecondaryButton("Confirm cancellation") {
                    viewModel.didTapConfirm()
                }
                .disabled(viewModel.isConfirming)
                PrimaryButton("Keep trip") {
                    viewModel.didTapKeepTrip()
                }
            }
        }
        .padding(24)
    }
}

#if DEBUG

extension DriverCancelTripScreen {
    /// Preview-only: shows a ready-made view model.
    init(previewViewModel: DriverCancelTripViewModel) {
        _viewModel = State(wrappedValue: previewViewModel)
    }
}

#Preview("Default") {
    DriverCancelTripScreen(previewViewModel: DriverCancelTripViewModel())
}

#Preview("Reason selected") {
    DriverCancelTripScreen(previewViewModel: DriverCancelTripViewModel(reason: .vehicleIssue))
}

#Preview("Confirming") {
    DriverCancelTripScreen(previewViewModel: DriverCancelTripViewModel(isLoading: true))
}

#endif
