import SwiftUI

/// Lets the rider share their referral code and redeem a friend's.
public struct ReferralScreen: View {
    @State private var viewModel: ReferralViewModel

    public init(store: ReferralStore, onRedeemed: @escaping (Money) async -> Void, viewModel: ReferralViewModel? = nil) {
        _viewModel = State(wrappedValue: viewModel ?? ReferralViewModel(store: store, onRedeemed: onRedeemed))
    }

    public var body: some View {
        @Bindable var viewModel = viewModel
        List {
            Section("Your Referral Code") {
                HStack {
                    Text(viewModel.myCode)
                        .font(BrandTypography.title)
                    Spacer()
                    ShareLink(item: viewModel.shareMessage) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share referral code")
                }
                Text(viewModel.explanation)
                    .font(BrandTypography.caption)
                    .foregroundStyle(BrandColor.textSecondary)
            }

            Section("Redeem a Code") {
                TextField("Friend's code", text: $viewModel.codeInput)
                    .textInputAutocapitalization(.characters)
                SecondaryButton("Redeem") { viewModel.didTapRedeem() }
                    .disabled(!viewModel.canRedeem)
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(BrandTypography.caption)
                        .foregroundStyle(BrandColor.danger)
                }
                if let successMessage = viewModel.successMessage {
                    Text(successMessage)
                        .font(BrandTypography.caption)
                        .foregroundStyle(BrandColor.success)
                }
            }

            if viewModel.hasEarnedCredit {
                Section("Total Earned") {
                    Text(viewModel.creditEarned.formatted)
                        .font(BrandTypography.headline)
                }
            }
        }
        .navigationTitle("Refer & Earn")
    }
}

#if DEBUG

#Preview("Data") {
    NavigationStack {
        ReferralScreen(store: .mock(), onRedeemed: { _ in }, viewModel: ReferralViewModel())
    }
}

#Preview("Empty") {
    NavigationStack {
        ReferralScreen(store: .mock(), onRedeemed: { _ in }, viewModel: ReferralViewModel(isEmptyView: true))
    }
}

#Preview("Redeeming") {
    NavigationStack {
        ReferralScreen(store: .mock(), onRedeemed: { _ in }, viewModel: ReferralViewModel(isLoading: true))
    }
}

#Preview("Redeem error") {
    NavigationStack {
        ReferralScreen(store: .mock(), onRedeemed: { _ in }, viewModel: ReferralViewModel(isError: true))
    }
}

#endif
