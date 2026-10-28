import SwiftUI

/// Card listing trip-count incentives. Hidden when there are none. Only `.completed` ones show a
/// Claim button; `isClaiming` disables all buttons so only one claim runs at a time.
public struct IncentivesList: View {
    let incentives: [DriverIncentive]
    let isClaiming: Bool
    let onClaim: (DriverIncentive) -> Void

    public init(incentives: [DriverIncentive], isClaiming: Bool, onClaim: @escaping (DriverIncentive) -> Void) {
        self.incentives = incentives
        self.isClaiming = isClaiming
        self.onClaim = onClaim
    }

    public var body: some View {
        if !incentives.isEmpty {
            SectionCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Incentives")
                        .font(BrandTypography.title)
                    ForEach(incentives) { incentive in
                        IncentiveRow(incentive: incentive, isClaiming: isClaiming, onClaim: { onClaim(incentive) })
                        if incentive.id != incentives.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

/// One incentive: title, reward, progress bar and its status (nothing / Claim / Claimed).
private struct IncentiveRow: View {
    let incentive: DriverIncentive
    let isClaiming: Bool
    let onClaim: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(incentive.title)
                        .font(BrandTypography.headline)
                    Text(incentive.description)
                        .font(BrandTypography.caption)
                        .foregroundStyle(BrandColor.textSecondary)
                }
                Spacer()
                Text(incentive.reward.formatted)
                    .font(BrandTypography.headline)
                    .foregroundStyle(BrandColor.primary)
            }

            ProgressView(value: incentive.progress)
                .tint(BrandColor.primary)

            HStack {
                Text("\(incentive.currentTrips)/\(incentive.targetTrips) trips")
                    .font(BrandTypography.caption)
                    .foregroundStyle(BrandColor.textSecondary)
                Spacer()
                switch incentive.status {
                case .inProgress:
                    EmptyView()
                case .completed:
                    SecondaryButton("Claim", action: onClaim)
                        .disabled(isClaiming)
                        .fixedSize()
                case .claimed:
                    Label("Claimed", systemImage: "checkmark.circle.fill")
                        .font(BrandTypography.caption)
                        .foregroundStyle(BrandColor.success)
                }
            }
        }
    }
}

#if DEBUG

#Preview("None") {
    IncentivesList(incentives: [], isClaiming: false, onClaim: { _ in })
        .padding()
}

#Preview("In progress") {
    IncentivesList(incentives: [.mock(status: .inProgress)], isClaiming: false, onClaim: { _ in })
        .padding()
}

#Preview("Completed, claimable") {
    IncentivesList(incentives: [.mock(currentTrips: 10, status: .completed)], isClaiming: false, onClaim: { _ in })
        .padding()
}

#Preview("Claimed") {
    IncentivesList(incentives: [.mock(currentTrips: 10, status: .claimed)], isClaiming: false, onClaim: { _ in })
        .padding()
}

#Preview("Incentive row") {
    IncentiveRow(incentive: .mock(currentTrips: 10, status: .completed), isClaiming: true, onClaim: {})
        .padding()
}

#endif
