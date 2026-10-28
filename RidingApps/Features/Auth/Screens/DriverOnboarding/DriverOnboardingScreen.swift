import SwiftUI

/// Step 5 (drivers only): ID, licence and vehicle details, required before going online.
public struct DriverOnboardingScreen: View {
    @State private var viewModel: DriverOnboardingViewModel

    /// - Parameter initialVerification: earlier values to prefill (used when resubmitting after a rejection).
    public init(
        userId: String,
        initialVerification: DriverVerification? = nil,
        onSubmitted: @escaping (DriverVerification) -> Void,
        viewModel: DriverOnboardingViewModel? = nil
    ) {
        _viewModel = State(wrappedValue: viewModel ?? DriverOnboardingViewModel(
            userId: userId,
            initialVerification: initialVerification,
            onSubmitted: onSubmitted
        ))
    }

    public var body: some View {
        @Bindable var viewModel = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Driver ID verification")
                        .font(BrandTypography.largeTitle)
                        .foregroundStyle(BrandColor.textPrimary)
                    Text("We need to verify your identity and vehicle before you can go online and accept trips.")
                        .font(BrandTypography.body)
                        .foregroundStyle(BrandColor.textSecondary)
                }

                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(errorMessage)
                }

                SectionCard {
                    VStack(alignment: .leading, spacing: 16) {
                        LabeledTextField(label: "National ID number", text: $viewModel.nidNumber, keyboardType: .numberPad)
                        LabeledTextField(label: "Driving license number", text: $viewModel.drivingLicenseNumber)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Vehicle type")
                                .font(BrandTypography.caption)
                                .foregroundStyle(BrandColor.textSecondary)
                            Picker("Vehicle type", selection: $viewModel.vehicleType) {
                                ForEach(VehicleType.allCases) { type in
                                    Label(type.displayName, systemImage: type.systemImageName)
                                        .tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        LabeledTextField(label: "Vehicle registration plate", text: $viewModel.vehicleRegistrationPlate)
                    }
                }

                PrimaryButton("Submit for Verification", isLoading: viewModel.isLoading) {
                    viewModel.didTapSubmit()
                }
            }
            .padding(20)
        }
        .background(BrandColor.background)
    }
}

#if DEBUG

#Preview("Empty") {
    NavigationStack {
        DriverOnboardingScreen(
            userId: "driver-1",
            onSubmitted: { _ in },
            viewModel: DriverOnboardingViewModel(isPreview: true)
        )
    }
}

#Preview("Prefilled (resubmit)") {
    NavigationStack {
        DriverOnboardingScreen(
            userId: "driver-1",
            onSubmitted: { _ in },
            viewModel: DriverOnboardingViewModel(isPreview: true, initialVerification: .mock(status: .rejected))
        )
    }
}

#Preview("Loading") {
    NavigationStack {
        DriverOnboardingScreen(
            userId: "driver-1",
            onSubmitted: { _ in },
            viewModel: DriverOnboardingViewModel(isPreview: true, initialVerification: .mock(status: .pending), isLoading: true)
        )
    }
}

#Preview("Error") {
    NavigationStack {
        DriverOnboardingScreen(
            userId: "driver-1",
            onSubmitted: { _ in },
            viewModel: DriverOnboardingViewModel(
                isPreview: true,
                errorMessage: "Could not submit verification. Please try again."
            )
        )
    }
}

#endif
