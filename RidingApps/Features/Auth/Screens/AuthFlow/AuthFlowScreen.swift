import SwiftUI

/// Container for the login / sign-up flow. It shows whichever step `AuthFlowViewModel` says is
/// current (phone -> code -> role -> profile -> driver documents). `RootScreen` shows this
/// whenever nobody is logged in.
public struct AuthFlowScreen: View {
    @State private var viewModel: AuthFlowViewModel

    /// - Parameter onAuthenticated: called once with the finished user (and driver verification,
    ///   for drivers) and the login tokens when the whole flow completes.
    public init(
        onAuthenticated: @escaping (AppUser, DriverVerification?, SessionTokens?) -> Void,
        viewModel: AuthFlowViewModel? = nil
    ) {
        _viewModel = State(wrappedValue: viewModel ?? AuthFlowViewModel(onAuthenticated: onAuthenticated))
    }

    public var body: some View {
        NavigationStack {
            Group {
                #if DEBUG
                if viewModel.isPreviewFlow {
                    previewStep
                } else {
                    liveStep
                }
                #else
                liveStep
                #endif
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.canGoBack {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewModel.didTapBack()
                        } label: {
                            Label(backTitle, systemImage: "chevron.left")
                        }
                        .tint(BrandColor.primary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var liveStep: some View {
        switch viewModel.step {
        case .phoneEntry:
            PhoneEntryScreen(initialPhoneNumber: viewModel.phoneNumber, onCodeSent: viewModel.didSendCode)
        case .otpEntry:
            OTPEntryScreen(phoneNumber: viewModel.phoneNumber, onVerified: { viewModel.didVerifyCode(user: $0.user, tokens: $0.tokens) })
        case .roleSelection:
            RoleSelectionScreen(onSelectRole: viewModel.didSelectRole)
        case .profileDetails:
            ProfileDetailsScreen(
                role: viewModel.selectedRole,
                initialGender: viewModel.profileGender,
                initialWomenSafeMode: viewModel.profileWomenSafeMode,
                onContinue: viewModel.didCompleteProfile
            )
        case .driverOnboarding:
            DriverOnboardingScreen(userId: viewModel.currentUser?.id ?? "", onSubmitted: viewModel.didSubmitDriverVerification)
        case .done:
            // Brief spinner while RootScreen swaps to the rider/driver flow.
            ProgressView()
        }
    }

    /// "Change number" on the code step, plain "Back" elsewhere.
    private var backTitle: String {
        viewModel.step == .otpEntry ? String(localized: "Change number") : String(localized: "Back")
    }
}

#if DEBUG

private extension AuthFlowScreen {
    /// Same steps as `liveStep`, but each screen gets a preview view model so nothing hits a repository.
    @ViewBuilder
    var previewStep: some View {
        switch viewModel.step {
        case .phoneEntry:
            PhoneEntryScreen(
                initialPhoneNumber: viewModel.phoneNumber,
                onCodeSent: viewModel.didSendCode,
                viewModel: PhoneEntryViewModel(isPreview: true, phoneNumber: viewModel.phoneNumber)
            )
        case .otpEntry:
            OTPEntryScreen(
                phoneNumber: viewModel.phoneNumber,
                onVerified: { _ in },
                viewModel: OTPEntryViewModel(isPreview: true, phoneNumber: viewModel.phoneNumber, resendSecondsRemaining: 25)
            )
        case .roleSelection:
            RoleSelectionScreen(onSelectRole: viewModel.didSelectRole)
        case .profileDetails:
            ProfileDetailsScreen(
                role: viewModel.selectedRole,
                onContinue: viewModel.didCompleteProfile,
                viewModel: ProfileDetailsViewModel(
                    isPreview: true,
                    role: viewModel.selectedRole,
                    gender: viewModel.profileGender,
                    womenSafeModeEnabled: viewModel.profileWomenSafeMode
                )
            )
        case .driverOnboarding:
            DriverOnboardingScreen(
                userId: viewModel.currentUser?.id ?? "",
                onSubmitted: viewModel.didSubmitDriverVerification,
                viewModel: DriverOnboardingViewModel(isPreview: true)
            )
        case .done:
            ProgressView()
        }
    }
}

#Preview("Phone entry") {
    AuthFlowScreen(onAuthenticated: { _, _, _ in }, viewModel: AuthFlowViewModel(isPreview: true, step: .phoneEntry))
}

#Preview("Code entry") {
    AuthFlowScreen(onAuthenticated: { _, _, _ in }, viewModel: AuthFlowViewModel(isPreview: true, step: .otpEntry))
}

#Preview("Role selection") {
    AuthFlowScreen(onAuthenticated: { _, _, _ in }, viewModel: AuthFlowViewModel(isPreview: true, step: .roleSelection))
}

#Preview("Profile (rider)") {
    AuthFlowScreen(onAuthenticated: { _, _, _ in }, viewModel: AuthFlowViewModel(isPreview: true, step: .profileDetails))
}

#Preview("Profile (driver)") {
    AuthFlowScreen(
        onAuthenticated: { _, _, _ in },
        viewModel: AuthFlowViewModel(isPreview: true, step: .profileDetails, role: .driver)
    )
}

#Preview("Driver documents") {
    AuthFlowScreen(
        onAuthenticated: { _, _, _ in },
        viewModel: AuthFlowViewModel(isPreview: true, step: .driverOnboarding, role: .driver, gender: .male)
    )
}

#endif
