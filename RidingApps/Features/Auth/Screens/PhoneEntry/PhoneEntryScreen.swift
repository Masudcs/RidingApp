import SwiftUI

/// Step 1: asks for the phone number and sends the verification code.
public struct PhoneEntryScreen: View {
    @State private var viewModel: PhoneEntryViewModel

    /// - Parameter initialPhoneNumber: prefilled number, e.g. when returning from the code step.
    public init(
        initialPhoneNumber: String = "",
        onCodeSent: @escaping (String) -> Void,
        viewModel: PhoneEntryViewModel? = nil
    ) {
        _viewModel = State(wrappedValue: viewModel ?? PhoneEntryViewModel(initialPhoneNumber: initialPhoneNumber, onCodeSent: onCodeSent))
    }

    public var body: some View {
        @Bindable var viewModel = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome")
                        .font(BrandTypography.largeTitle)
                        .foregroundStyle(BrandColor.textPrimary)
                    Text("Enter your phone number to get started.")
                        .font(BrandTypography.body)
                        .foregroundStyle(BrandColor.textSecondary)
                }

                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(errorMessage)
                }

                SectionCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Phone number")
                            .font(BrandTypography.caption)
                            .foregroundStyle(BrandColor.textSecondary)
                        TextField("+880 1XXX-XXXXXX", text: $viewModel.phoneNumber)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .font(BrandTypography.body)
                    }
                }

                PrimaryButton("Send Code", isLoading: viewModel.isLoading) {
                    viewModel.didTapSendCode()
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
        PhoneEntryScreen(onCodeSent: { _ in }, viewModel: PhoneEntryViewModel(isPreview: true))
    }
}

#Preview("Filled") {
    NavigationStack {
        PhoneEntryScreen(
            onCodeSent: { _ in },
            viewModel: PhoneEntryViewModel(isPreview: true, phoneNumber: "+880 1700-000000")
        )
    }
}

#Preview("Loading") {
    NavigationStack {
        PhoneEntryScreen(
            onCodeSent: { _ in },
            viewModel: PhoneEntryViewModel(isPreview: true, phoneNumber: "+880 1700-000000", isLoading: true)
        )
    }
}

#Preview("Error") {
    NavigationStack {
        PhoneEntryScreen(
            onCodeSent: { _ in },
            viewModel: PhoneEntryViewModel(
                isPreview: true,
                phoneNumber: "+880 1700-000000",
                errorMessage: "Could not send code. Please try again."
            )
        )
    }
}

#endif
