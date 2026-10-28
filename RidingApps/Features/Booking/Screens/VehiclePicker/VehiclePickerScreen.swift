import SwiftUI

/// Root screen of the booking stack: pick a vehicle type, then continue to the location step.
public struct VehiclePickerScreen: View {
    @State private var viewModel: VehiclePickerViewModel

    public init(onContinue: @escaping (VehicleType) -> Void) {
        _viewModel = State(wrappedValue: VehiclePickerViewModel(onContinue: onContinue))
    }

    public var body: some View {
        VStack(spacing: 20) {
            Text("Choose a vehicle")
                .font(BrandTypography.title)
                .padding(.horizontal, 16)

            VehiclePickerView(selected: viewModel.selectedVehicleType) { vehicleType in
                viewModel.didSelectVehicle(vehicleType)
            }

            Spacer()

            PrimaryButton("Continue") {
                viewModel.didTapContinue()
            }
            .padding(16)
        }
        .padding(.top, 16)
        .background(BrandColor.background)
    }
}

#if DEBUG

extension VehiclePickerScreen {
    /// Preview-only: shows a ready-made view model.
    init(previewViewModel: VehiclePickerViewModel) {
        _viewModel = State(wrappedValue: previewViewModel)
    }
}

#Preview("Car selected") {
    VehiclePickerScreen(previewViewModel: VehiclePickerViewModel(selected: .car))
}

#Preview("Bike selected") {
    VehiclePickerScreen(previewViewModel: VehiclePickerViewModel(selected: .bike))
}

#Preview("Premium selected") {
    VehiclePickerScreen(previewViewModel: VehiclePickerViewModel(selected: .premium))
}

#endif
