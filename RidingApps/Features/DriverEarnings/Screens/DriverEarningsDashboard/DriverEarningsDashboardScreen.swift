import SwiftUI

/// Root of the driver's Earnings tab: balance summary, cash-out button, incentives and history.
/// Loads on appear; the cash-out flow is presented as a sheet.
public struct DriverEarningsDashboardScreen: View {
    @State private var viewModel: DriverEarningsDashboardViewModel

    public init(viewModel: DriverEarningsDashboardViewModel? = nil) {
        _viewModel = State(wrappedValue: viewModel ?? DriverEarningsDashboardViewModel())
    }

    public var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let errorMessage = viewModel.errorMessage {
                        ErrorBanner(errorMessage)
                    }

                    switch viewModel.state {
                    case .loading:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    case .error:
                        EmptyView()
                    case let .data(content):
                        EarningsSummaryCard(summary: content.summary)
                        if let statementText = viewModel.statementText {
                            ShareLink(item: statementText) {
                                Label("Share Weekly Statement", systemImage: "doc.text")
                            }
                            .font(BrandTypography.body)
                        }
                    }

                    PrimaryButton("Cash Out", systemImage: "arrow.down.circle.fill") {
                        viewModel.didTapCashOut()
                    }
                    // No balance yet (loading or failed) means nothing to cash out.
                    .disabled(viewModel.availableBalance == nil)

                    if let content = viewModel.state.data {
                        IncentivesList(incentives: content.incentives, isClaiming: viewModel.isClaimingIncentive) { incentive in
                            viewModel.didTapClaim(incentive)
                        }

                        CashOutHistoryList(history: content.history)
                    } else {
                        CashOutHistoryList(history: [])
                    }
                }
                .padding(20)
            }
            // Also the only retry path after a failed load.
            .refreshable { await viewModel.onAppear() }
            .navigationTitle("Earnings")
            .background(BrandColor.background)
            .task {
                await viewModel.onAppear()
            }
            .sheet(isPresented: $viewModel.isPresentingCashOut) {
                CashOutScreen(availableBalance: viewModel.availableBalance) {
                    viewModel.didCompleteCashOut()
                }
            }
        }
    }
}

#if DEBUG

#Preview("Loading") {
    DriverEarningsDashboardScreen(viewModel: DriverEarningsDashboardViewModel(isPreview: true, isLoading: true))
}

#Preview("Data") {
    DriverEarningsDashboardScreen(viewModel: DriverEarningsDashboardViewModel(isPreview: true))
}

#Preview("Empty") {
    DriverEarningsDashboardScreen(viewModel: DriverEarningsDashboardViewModel(isPreview: true, isEmptyView: true))
}

#Preview("Error") {
    DriverEarningsDashboardScreen(viewModel: DriverEarningsDashboardViewModel(isPreview: true, isError: true))
}

#Preview("Claiming incentive") {
    DriverEarningsDashboardScreen(viewModel: DriverEarningsDashboardViewModel(isPreview: true, isClaiming: true))
}

#Preview("Claimed") {
    DriverEarningsDashboardScreen(viewModel: DriverEarningsDashboardViewModel(isPreview: true, isClaimed: true))
}

#endif
