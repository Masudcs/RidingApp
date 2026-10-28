import SwiftUI

/// Step 2: asks for the code that was sent to the phone. `.oneTimeCode` lets iOS suggest the
/// code from the incoming SMS above the keyboard.
public struct OTPEntryScreen: View {
    @State private var viewModel: OTPEntryViewModel

    public init(
        phoneNumber: String,
        onVerified: @escaping (AuthSession) -> Void,
        viewModel: OTPEntryViewModel? = nil
    ) {
        _viewModel = State(wrappedValue: viewModel ?? OTPEntryViewModel(phoneNumber: phoneNumber, onVerified: onVerified))
    }

    public var body: some View {
        @Bindable var viewModel = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Verify your number")
                        .font(BrandTypography.largeTitle)
                        .foregroundStyle(BrandColor.textPrimary)
                    Text("Enter the code we sent to \(viewModel.phoneNumber).")
                        .font(BrandTypography.body)
                        .foregroundStyle(BrandColor.textSecondary)
                }

                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(errorMessage)
                }

                SectionCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Verification code")
                            .font(BrandTypography.caption)
                            .foregroundStyle(BrandColor.textSecondary)
                        TextField("1234", text: $viewModel.otpCode)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .font(BrandTypography.body)
                    }
                }

                PrimaryButton("Verify", isLoading: viewModel.isLoading) {
                    viewModel.didTapVerify()
                }

                VStack(spacing: 8) {
                    if let message = viewModel.resendMessage {
                        Text(message)
                            .font(BrandTypography.caption)
                            .foregroundStyle(viewModel.resendFailed ? BrandColor.danger : BrandColor.success)
                    }
                    Button {
                        viewModel.didTapResend()
                    } label: {
                        Text(resendTitle)
                            .font(BrandTypography.headline)
                    }
                    .tint(BrandColor.primary)
                    .disabled(!viewModel.canResend)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
        .background(BrandColor.background)
        .onAppear { viewModel.startCooldownIfNeeded() }
        .onDisappear { viewModel.cancelTasks() }
    }

    /// "Resend code", or "Resend code in 25s" while the cooldown runs.
    private var resendTitle: String {
        viewModel.resendSecondsRemaining > 0
            ? String(localized: "Resend code in \(viewModel.resendSecondsRemaining)s")
            : String(localized: "Resend code")
    }
}

#if DEBUG

#Preview("Empty, cooldown running") {
    NavigationStack {
        OTPEntryScreen(
            phoneNumber: "+8801700000000",
            onVerified: { _ in },
            viewModel: OTPEntryViewModel(isPreview: true, resendSecondsRemaining: 25)
        )
    }
}

#Preview("Loading") {
    NavigationStack {
        OTPEntryScreen(
            phoneNumber: "+8801700000000",
            onVerified: { _ in },
            viewModel: OTPEntryViewModel(isPreview: true, otpCode: "1234", isLoading: true, resendSecondsRemaining: 18)
        )
    }
}

#Preview("Wrong code") {
    NavigationStack {
        OTPEntryScreen(
            phoneNumber: "+8801700000000",
            onVerified: { _ in },
            viewModel: OTPEntryViewModel(
                isPreview: true,
                otpCode: "0000",
                errorMessage: "Invalid code. Please try again.",
                resendSecondsRemaining: 12
            )
        )
    }
}

#Preview("Resend available") {
    NavigationStack {
        OTPEntryScreen(
            phoneNumber: "+8801700000000",
            onVerified: { _ in },
            viewModel: OTPEntryViewModel(isPreview: true)
        )
    }
}

#Preview("Resend sent") {
    NavigationStack {
        OTPEntryScreen(
            phoneNumber: "+8801700000000",
            onVerified: { _ in },
            viewModel: OTPEntryViewModel(
                isPreview: true,
                resendSecondsRemaining: 30,
                resendMessage: "A new code was sent."
            )
        )
    }
}

#Preview("Resend failed") {
    NavigationStack {
        OTPEntryScreen(
            phoneNumber: "+8801700000000",
            onVerified: { _ in },
            viewModel: OTPEntryViewModel(
                isPreview: true,
                resendSecondsRemaining: 30,
                resendMessage: "Could not resend the code.",
                resendFailed: true
            )
        )
    }
}

#endif
