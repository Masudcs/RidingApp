import SwiftUI

/// Shown by `RiderHomeScreen` when a trip ends: fare summary, tip, split, promo code and payment
/// method, then a Pay button. After a successful charge it shows the receipt card and the view
/// model reports back through `onPaymentCompleted`.
public struct PaymentCheckoutScreen: View {
    @State private var viewModel: PaymentCheckoutViewModel

    public init(
        trip: Trip,
        onPaymentCompleted: @escaping (PaymentReceipt) -> Void,
        viewModel: PaymentCheckoutViewModel? = nil
    ) {
        _viewModel = State(wrappedValue: viewModel ?? PaymentCheckoutViewModel(trip: trip, onPaymentCompleted: onPaymentCompleted))
    }

    public var body: some View {
        @Bindable var viewModel = viewModel
        ScrollView {
            VStack(spacing: 16) {
                SectionCard {
                    VStack(spacing: 4) {
                        Text(viewModel.amountTitle)
                            .font(BrandTypography.caption)
                            .foregroundStyle(BrandColor.textSecondary)
                        Text(viewModel.amountDue.formatted)
                            .font(BrandTypography.largeTitle)
                            .foregroundStyle(BrandColor.textPrimary)
                        if let savedText = viewModel.savedText {
                            Text(savedText)
                                .font(BrandTypography.caption)
                                .foregroundStyle(BrandColor.success)
                        }
                        if let splitSummary = viewModel.splitSummary {
                            Text(splitSummary)
                                .font(BrandTypography.caption)
                                .foregroundStyle(BrandColor.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                FareDetailsCard(rows: viewModel.fareRows, summaryRows: viewModel.fareSummaryRows)

                if viewModel.receipt == nil {
                    SectionCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Add a Tip")
                                .font(BrandTypography.title)
                            HStack(spacing: 8) {
                                ForEach(viewModel.tipPercentages, id: \.self) { percentage in
                                    SecondaryButton(viewModel.tipLabel(for: percentage)) {
                                        viewModel.didTapTip(percentage: percentage)
                                    }
                                }
                            }
                            if let tipText = viewModel.tipText {
                                Text(tipText)
                                    .font(BrandTypography.caption)
                                    .foregroundStyle(BrandColor.textSecondary)
                            }
                        }
                    }

                    SectionCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Split Fare")
                                    .font(BrandTypography.headline)
                                Text("Split evenly \u{2014} you're only charged your share")
                                    .font(BrandTypography.caption)
                                    .foregroundStyle(BrandColor.textSecondary)
                            }
                            Spacer()
                            Stepper("\(viewModel.splitCount)", value: $viewModel.splitCount, in: viewModel.splitRange)
                                .fixedSize()
                        }
                    }
                }

                if viewModel.receipt == nil {
                    SectionCard {
                        if let promo = viewModel.appliedPromo {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(promo.code)
                                        .font(BrandTypography.headline)
                                    Text(promo.description)
                                        .font(BrandTypography.caption)
                                        .foregroundStyle(BrandColor.textSecondary)
                                }
                                Spacer()
                                Button("Remove") {
                                    viewModel.didTapRemovePromo()
                                }
                                .font(BrandTypography.caption)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    TextField("Promo code", text: $viewModel.promoCodeInput)
                                        .textFieldStyle(.roundedBorder)
                                        .textInputAutocapitalization(.characters)
                                    Button("Apply") {
                                        Task { await viewModel.didTapApplyPromo() }
                                    }
                                    .disabled(!viewModel.canApplyPromo)
                                }
                                if let promoErrorMessage = viewModel.promoErrorMessage {
                                    Text(promoErrorMessage)
                                        .font(BrandTypography.caption)
                                        .foregroundStyle(BrandColor.danger)
                                }
                            }
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(errorMessage)
                }

                if let receipt = viewModel.receipt {
                    PaymentSuccessCard(receipt: receipt)
                } else {
                    SectionCard {
                        VStack(spacing: 0) {
                            PaymentMethodRow(
                                systemImageName: PaymentMethodType.wallet.systemImageName,
                                title: PaymentMethodType.wallet.displayName,
                                subtitle: viewModel.walletSubtitle(),
                                isSelected: viewModel.selectedMethod == .wallet
                            )
                            .onTapGesture { viewModel.didSelectMethod(.wallet) }

                            Divider()

                            ForEach(viewModel.savedMethods) { account in
                                PaymentMethodRow(
                                    systemImageName: account.type.systemImageName,
                                    title: account.type.displayName,
                                    subtitle: account.maskedIdentifier,
                                    isSelected: viewModel.selectedMethod == account.type
                                )
                                .onTapGesture { viewModel.didSelectMethod(account.type) }
                                Divider()
                            }

                            PaymentMethodRow(
                                systemImageName: PaymentMethodType.cash.systemImageName,
                                title: PaymentMethodType.cash.displayName,
                                subtitle: "Pay the driver directly",
                                isSelected: viewModel.selectedMethod == .cash
                            )
                            .onTapGesture { viewModel.didSelectMethod(.cash) }
                        }
                    }

                    PrimaryButton(
                        viewModel.payButtonTitle,
                        isLoading: viewModel.isProcessing,
                        isEnabled: !viewModel.isProcessing
                    ) {
                        Task { await viewModel.didTapPay() }
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

private func previewScreen(_ viewModel: PaymentCheckoutViewModel) -> some View {
    PaymentCheckoutScreen(trip: .mock(status: .completed), onPaymentCompleted: { _ in }, viewModel: viewModel)
}

#Preview("Data") {
    previewScreen(PaymentCheckoutViewModel())
}

#Preview("Empty methods") {
    previewScreen(PaymentCheckoutViewModel(isEmptyView: true))
}

#Preview("Promo applied") {
    previewScreen(PaymentCheckoutViewModel(promo: .mock()))
}

#Preview("Tip selected") {
    previewScreen(PaymentCheckoutViewModel(tipPercentage: 0.15))
}

#Preview("Split fare") {
    previewScreen(PaymentCheckoutViewModel(splitCount: 3))
}

#Preview("Paying") {
    previewScreen(PaymentCheckoutViewModel(isLoading: true))
}

#Preview("Payment error") {
    previewScreen(PaymentCheckoutViewModel(isError: true))
}

#Preview("Paid") {
    previewScreen(PaymentCheckoutViewModel(promo: .mock(), tipPercentage: 0.10, splitCount: 2, isPaid: true))
}

#endif
