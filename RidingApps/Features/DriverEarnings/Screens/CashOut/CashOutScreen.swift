import SwiftUI

/// Sheet opened from the earnings dashboard where the driver enters an amount, picks a payout
/// method and withdraws. Dismissal is blocked while a request is in flight so the result is not lost.
public struct CashOutScreen: View {
    @State private var viewModel: CashOutViewModel
    @Environment(\.dismiss) private var dismiss

    /// `availableBalance` powers "Cash out all"; `onCashedOut` fires after each settled request.
    public init(availableBalance: Money?, onCashedOut: @escaping () -> Void = {}, viewModel: CashOutViewModel? = nil) {
        _viewModel = State(wrappedValue: viewModel ?? CashOutViewModel(availableBalance: availableBalance, onCashedOut: onCashedOut))
    }

    public var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let lastCashOut = viewModel.lastCashOut, viewModel.errorMessage == nil {
                        successConfirmation(for: lastCashOut)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        ErrorBanner(errorMessage)
                    }

                    amountSection
                    destinationSection

                    PrimaryButton("Cash Out Now", isLoading: viewModel.isCashingOut) {
                        viewModel.didTapCashOut()
                    }
                }
                .padding(20)
            }
            .navigationTitle("Cash Out")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(viewModel.isCashingOut)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .disabled(viewModel.isCashingOut)
                }
            }
        }
    }

    private var amountSection: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Amount")
                    .font(BrandTypography.headline)
                    .foregroundStyle(BrandColor.textPrimary)

                HStack {
                    Text("\u{09F3}")
                        .font(BrandTypography.title)
                        .foregroundStyle(BrandColor.textSecondary)
                    TextField("0.00", text: $viewModel.amountText)
                        .keyboardType(.decimalPad)
                        .font(BrandTypography.title)
                }

                SecondaryButton("Cash out all", systemImage: "banknote") {
                    viewModel.didTapCashOutAll()
                }
            }
        }
    }

    private var destinationSection: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Send To")
                    .font(BrandTypography.headline)
                    .foregroundStyle(BrandColor.textPrimary)

                ForEach(PaymentMethodType.allCases) { method in
                    Button {
                        viewModel.didSelectDestination(method)
                    } label: {
                        HStack {
                            Image(systemName: method.systemImageName)
                            Text(method.displayName)
                                .font(BrandTypography.body)
                            Spacer()
                            if viewModel.selectedDestination == method {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(BrandColor.primary)
                            }
                        }
                        .foregroundStyle(BrandColor.textPrimary)
                        .padding(.vertical, 6)
                    }
                }
            }
        }
    }

    private func successConfirmation(for request: CashOutRequest) -> some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(BrandColor.success)
                    Text("Settled instantly")
                        .font(BrandTypography.headline)
                        .foregroundStyle(BrandColor.success)
                }
                Text("\(request.amount.formatted) to \(request.destination.displayName)")
                    .font(BrandTypography.body)
                    .foregroundStyle(BrandColor.textPrimary)
            }
        }
    }
}

#if DEBUG

#Preview("Idle") {
    CashOutScreen(availableBalance: .bdt(2_450), viewModel: CashOutViewModel())
}

#Preview("Amount typed") {
    CashOutScreen(availableBalance: .bdt(2_450), viewModel: CashOutViewModel(hasAmount: true))
}

#Preview("Invalid amount") {
    CashOutScreen(availableBalance: .bdt(2_450), viewModel: CashOutViewModel(isInvalidAmount: true))
}

#Preview("Cashing out") {
    CashOutScreen(availableBalance: .bdt(2_450), viewModel: CashOutViewModel(isCashingOut: true))
}

#Preview("Success") {
    CashOutScreen(availableBalance: .bdt(2_450), viewModel: CashOutViewModel(isSuccess: true))
}

#Preview("Failure") {
    CashOutScreen(availableBalance: .bdt(2_450), viewModel: CashOutViewModel(isFailure: true))
}

#endif
