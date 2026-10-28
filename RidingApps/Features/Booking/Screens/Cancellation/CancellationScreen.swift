import SwiftUI

/// Sheet shown before a rider cancels: explains the fee (if any) and asks why.
public struct CancellationScreen: View {
    @State private var viewModel: CancellationViewModel

    /// Bump this each time the caller's cancel request fails, so the confirm button works again.
    private let confirmationFailureCount: Int

    public init(
        trip: Trip,
        confirmationFailureCount: Int = 0,
        onConfirm: @escaping (CancellationReason, Money) -> Void,
        onKeepRide: @escaping () -> Void
    ) {
        self.confirmationFailureCount = confirmationFailureCount
        _viewModel = State(wrappedValue: CancellationViewModel(trip: trip, onConfirm: onConfirm, onKeepRide: onKeepRide))
    }

    public var body: some View {
        @Bindable var viewModel = viewModel
        let quote = viewModel.quote
        return VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: quote.isFree ? "xmark.circle" : "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(quote.isFree ? BrandColor.textSecondary : BrandColor.warning)
                Text("Cancel this ride?")
                    .font(BrandTypography.title)
                Text(quote.explanation)
                    .font(BrandTypography.body)
                    .foregroundStyle(BrandColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Why are you cancelling?")
                    .font(BrandTypography.headline)
                Picker("Reason", selection: $viewModel.selectedReason) {
                    ForEach(CancellationReason.allCases) { reason in
                        Text(reason.displayName).tag(reason)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxHeight: 140)
            }

            VStack(spacing: 12) {
                SecondaryButton(viewModel.confirmTitle) {
                    viewModel.didTapConfirm()
                }
                .disabled(viewModel.isConfirming)
                PrimaryButton("Keep my ride") {
                    viewModel.didTapKeepRide()
                }
            }
        }
        .padding(24)
        .onChange(of: confirmationFailureCount) { _ in
            viewModel.didFailConfirmation()
        }
    }
}

#if DEBUG

extension CancellationScreen {
    /// Preview-only: shows a ready-made view model.
    init(previewViewModel: CancellationViewModel) {
        confirmationFailureCount = 0
        _viewModel = State(wrappedValue: previewViewModel)
    }
}

#Preview("Free - no driver yet") {
    CancellationScreen(previewViewModel: CancellationViewModel(trip: .mock(status: .searchingDriver)))
}

#Preview("Free - inside window") {
    CancellationScreen(previewViewModel: CancellationViewModel(trip: .mock(status: .driverAssigned)))
}

#Preview("Fee applies") {
    CancellationScreen(previewViewModel: CancellationViewModel(trip: .mockPastFreeCancellationWindow(), reason: .driverNotMoving))
}

#Preview("Confirming") {
    CancellationScreen(previewViewModel: CancellationViewModel(trip: .mockPastFreeCancellationWindow(), isLoading: true))
}

#Preview("Trip in progress") {
    CancellationScreen(previewViewModel: CancellationViewModel(trip: .mock(status: .inProgress)))
}

#endif
