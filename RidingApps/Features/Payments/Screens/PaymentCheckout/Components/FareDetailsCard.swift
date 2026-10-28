import SwiftUI

/// Collapsible fare breakdown. `rows` are the computed fare parts; `summaryRows` (suggested vs
/// negotiated fare, insurance) are listed below a divider.
struct FareDetailsCard: View {
    let rows: [PaymentCheckoutViewModel.FareRow]
    let summaryRows: [PaymentCheckoutViewModel.FareRow]

    var body: some View {
        SectionCard {
            DisclosureGroup("Fare Details") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(rows) { row in
                        breakdownRow(row.title, row.amount)
                    }
                    Divider()
                    ForEach(summaryRows) { row in
                        breakdownRow(row.title, row.amount)
                    }
                }
                .padding(.top, 8)
            }
            .font(BrandTypography.headline)
        }
    }

    private func breakdownRow(_ title: String, _ amount: Money) -> some View {
        HStack {
            Text(title)
                .font(BrandTypography.body)
                .foregroundStyle(BrandColor.textSecondary)
            Spacer()
            Text(amount.formatted)
                .font(BrandTypography.body)
                .foregroundStyle(BrandColor.textPrimary)
        }
    }
}

#if DEBUG

#Preview("Data") {
    let viewModel = PaymentCheckoutViewModel()
    return FareDetailsCard(rows: viewModel.fareRows, summaryRows: viewModel.fareSummaryRows)
        .padding()
        .background(BrandColor.background)
}

#endif
