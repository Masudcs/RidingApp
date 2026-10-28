import SwiftUI

/// Card listing past cash-outs (newest first, as given by the repository) with a status badge.
/// Shows an empty message when there are none, including while the dashboard is still loading.
public struct CashOutHistoryList: View {
    private let history: [CashOutRequest]

    public init(history: [CashOutRequest]) {
        self.history = history
    }

    public var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Cash-Out History")
                    .font(BrandTypography.headline)
                    .foregroundStyle(BrandColor.textPrimary)

                if history.isEmpty {
                    Text("No cash-outs yet.")
                        .font(BrandTypography.body)
                        .foregroundStyle(BrandColor.textSecondary)
                } else {
                    ForEach(history) { request in
                        row(for: request)
                        if request.id != history.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func row(for request: CashOutRequest) -> some View {
        HStack(spacing: 12) {
            Image(systemName: request.destination.systemImageName)
                .foregroundStyle(BrandColor.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(request.amount.formatted)
                    .font(BrandTypography.body)
                    .foregroundStyle(BrandColor.textPrimary)
                Text("\(request.destination.displayName) \u{00B7} \(request.requestedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(BrandTypography.caption)
                    .foregroundStyle(BrandColor.textSecondary)
            }

            Spacer()

            statusLabel(for: request.status)
        }
        .padding(.vertical, 4)
    }

    private func statusLabel(for status: CashOutStatus) -> some View {
        let (text, color): (String, Color) = {
            switch status {
            case .processing: return (String(localized: "Processing"), BrandColor.warning)
            case .settled: return (String(localized: "Settled"), BrandColor.success)
            case .failed: return (String(localized: "Failed"), BrandColor.danger)
            }
        }()

        return Text(text)
            .font(BrandTypography.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

#if DEBUG

#Preview("Empty") {
    CashOutHistoryList(history: [])
        .padding()
}

#Preview("Several entries") {
    CashOutHistoryList(history: CashOutRequest.mockList())
        .padding()
}

#endif
