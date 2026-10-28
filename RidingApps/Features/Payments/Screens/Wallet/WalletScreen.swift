import SwiftUI

/// The rider's Wallet tab: in-app balance, add money, saved/linkable payment methods and recent
/// payments. All state and actions live in `WalletViewModel`.
public struct WalletScreen: View {
    @State private var viewModel: WalletViewModel

    public init(viewModel: WalletViewModel? = nil) {
        _viewModel = State(wrappedValue: viewModel ?? WalletViewModel())
    }

    public var body: some View {
        @Bindable var viewModel = viewModel
        ScrollView {
            VStack(spacing: 16) {
                SectionCard {
                    VStack(spacing: 6) {
                        Label("In-App Wallet", systemImage: PaymentMethodType.wallet.systemImageName)
                            .font(BrandTypography.headline)
                            .foregroundStyle(BrandColor.textSecondary)
                        Text(viewModel.balance.formatted)
                            .font(BrandTypography.largeTitle)
                            .foregroundStyle(BrandColor.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                }

                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(errorMessage)
                }

                SectionCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add Money")
                            .font(BrandTypography.title)

                        HStack(spacing: 8) {
                            ForEach(viewModel.topUpPresets, id: \.self) { preset in
                                SecondaryButton("\u{09F3}\(preset)") {
                                    viewModel.didTapPreset(preset)
                                }
                            }
                        }

                        TextField("Amount (BDT)", text: $viewModel.topUpAmountInput)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)

                        Picker("From", selection: $viewModel.topUpMethod) {
                            ForEach(viewModel.linkableMethods) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)

                        PrimaryButton(
                            "Add Money",
                            isLoading: viewModel.isToppingUp,
                            isEnabled: viewModel.canTopUp
                        ) {
                            Task { await viewModel.didTapTopUp() }
                        }
                    }
                }

                SectionCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Saved Methods")
                            .font(BrandTypography.title)
                        if viewModel.savedMethods.isEmpty {
                            Text("No saved methods yet.")
                                .font(BrandTypography.caption)
                                .foregroundStyle(BrandColor.textSecondary)
                        } else {
                            ForEach(viewModel.savedMethods) { account in
                                PaymentMethodRow(
                                    systemImageName: account.type.systemImageName,
                                    title: account.type.displayName,
                                    subtitle: account.maskedIdentifier
                                )
                            }
                        }
                    }
                }

                SectionCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add Payment Method")
                            .font(BrandTypography.title)

                        Picker("Type", selection: $viewModel.newMethodType) {
                            ForEach(viewModel.linkableMethods) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)

                        TextField("Account number or card identifier", text: $viewModel.newMethodIdentifier)
                            .textFieldStyle(.roundedBorder)

                        SecondaryButton("Link") {
                            Task { await viewModel.didTapLinkMethod() }
                        }
                        .disabled(viewModel.isLinkingMethod)
                    }
                }

                SectionCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Payments")
                            .font(BrandTypography.title)
                        if viewModel.history.isEmpty {
                            Text("No payments yet.")
                                .font(BrandTypography.caption)
                                .foregroundStyle(BrandColor.textSecondary)
                        } else {
                            ForEach(viewModel.history) { receipt in
                                PaymentReceiptRow(
                                    title: receipt.method.displayName,
                                    dateText: viewModel.dateText(for: receipt),
                                    amountText: receipt.amount.formatted
                                )
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(BrandColor.background)
        .task {
            await viewModel.load()
        }
    }
}

#if DEBUG

#Preview("Loading") {
    WalletScreen(viewModel: WalletViewModel(isLoading: true))
}

#Preview("Data") {
    WalletScreen(viewModel: WalletViewModel())
}

#Preview("Empty") {
    WalletScreen(viewModel: WalletViewModel(isEmptyView: true))
}

#Preview("Top-up error") {
    WalletScreen(viewModel: WalletViewModel(isError: true))
}

#Preview("Adding money") {
    WalletScreen(viewModel: WalletViewModel(isToppingUp: true))
}

#endif
