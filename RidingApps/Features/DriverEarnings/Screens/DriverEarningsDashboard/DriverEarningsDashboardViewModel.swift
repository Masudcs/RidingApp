import Observation
import Foundation

/// Everything the dashboard shows once loaded, fetched together so the screen never mixes data
/// from different moments.
public struct DriverEarningsDashboardContent: Equatable {
    public var summary: DriverEarningsSummary
    public var history: [CashOutRequest]
    public var incentives: [DriverIncentive]
}

/// Drives the Earnings tab: loads balance, cash-out history and incentives, and handles claiming
/// rewards. The cash-out itself happens in `CashOutViewModel`; this class refreshes afterwards.
@MainActor
@Observable
public final class DriverEarningsDashboardViewModel {
    public private(set) var state: UIState<DriverEarningsDashboardContent> = .loading
    /// True while a claim request is running; disables every Claim button.
    public private(set) var isClaimingIncentive: Bool = false
    /// Error from a user action (claim, post-cash-out refresh). Cleared on the next load or claim.
    public private(set) var actionErrorMessage: String?
    public var isPresentingCashOut: Bool = false

    @ObservationIgnored private let repository: IDriverEarningsRepository
    /// Idempotency key per incentive being claimed; kept across failed attempts, dropped on a final outcome.
    @ObservationIgnored private var claimKeys: [String: String] = [:]
    @ObservationIgnored private let logger = AppLogger(category: "DriverEarningsViewModel")
    @ObservationIgnored private var isPreview = false

    public init(
        repository: IDriverEarningsRepository = AppEnvironment.current.usesMockServices ? MockDriverEarningsRepository.shared : DriverEarningsRepository()
    ) {
        self.repository = repository
    }

    /// Load error if the screen has no data, otherwise the last action error.
    public var errorMessage: String? {
        if case let .error(message) = state { return message }
        return actionErrorMessage
    }

    /// Nil until the first load succeeds; the cash-out sheet uses it for "Cash out all".
    public var availableBalance: Money? {
        state.data?.summary.availableBalance
    }

    /// A plain-text weekly statement, exported via `ShareLink` rather than a generated PDF — good
    /// enough for a driver's own record-keeping without needing a PDF-rendering dependency.
    public var statementText: String? {
        guard let content = state.data else { return nil }
        let summary = content.summary
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        var lines = [
            String(localized: "RidingApps \u{2014} Weekly Earnings Statement"),
            "Week earnings: \(summary.weekEarnings.formatted)",
            "Today: \(summary.todayEarnings.formatted) across \(summary.completedTripsToday) trips",
            "Available balance: \(summary.availableBalance.formatted)",
            ""
        ]

        if content.history.isEmpty {
            lines.append(String(localized: "No cash-outs this period."))
        } else {
            lines.append(String(localized: "Cash-outs this period:"))
            for request in content.history {
                lines.append("- \(request.amount.formatted) to \(request.destination.displayName) \u{2014} \(request.status.rawValue) \(dateFormatter.string(from: request.requestedAt))")
            }
        }

        return lines.joined(separator: "\n")
    }

    /// Loads all three sections in parallel; any one failing fails the whole load, so the screen
    /// never shows a balance next to a stale history. Keeps old data visible while refreshing.
    /// Cancellation (tab switched away) is not an error and leaves the state alone.
    public func onAppear() async {
        guard !isPreview else { return }
        actionErrorMessage = nil
        if !state.hasData { state = .loading }
        do {
            async let summaryTask = repository.fetchSummary()
            async let historyTask = repository.fetchCashOutHistory()
            async let incentivesTask = repository.fetchIncentives()
            let content = DriverEarningsDashboardContent(
                summary: try await summaryTask,
                history: try await historyTask,
                incentives: try await incentivesTask
            )
            state = .data(data: content)
        } catch is CancellationError {
            return
        } catch {
            logger.error("Failed to load driver earnings: \(error.localizedDescription)")
            if state.hasData {
                // Keep showing the last good data; just tell the driver the refresh failed.
                actionErrorMessage = String(localized: "Couldn't refresh your earnings. Please try again.")
            } else {
                state = .error(message: String(localized: "Couldn't load your earnings. Please try again."))
            }
        }
    }

    public func didTapCashOut() {
        isPresentingCashOut = true
    }

    public func didTapClaim(_ incentive: DriverIncentive) {
        guard !isPreview else { return }
        guard !isClaimingIncentive else { return }
        // Set before the Task starts so a fast second tap cannot begin a second claim.
        isClaimingIncentive = true
        Task { await claim(incentive) }
    }

    /// Called by the cash-out sheet once a request settles, so the balance and history stay current.
    /// Re-reads `state` after the network calls so it does not overwrite changes made meanwhile.
    public func didCompleteCashOut() {
        guard !isPreview else { return }
        Task {
            do {
                let summary = try await repository.fetchSummary()
                let history = try await repository.fetchCashOutHistory()
                guard var content = state.data else { return }
                content.summary = summary
                content.history = history
                state = .data(data: content)
            } catch {
                // The cash-out already succeeded; only the refresh failed, so say the numbers may be old.
                logger.error("Failed to refresh after cash-out: \(error.localizedDescription)")
                actionErrorMessage = String(localized: "Cash-out went through, but we couldn't refresh your balance. Pull to reload.")
            }
        }
    }

    /// `isClaimingIncentive` is already true here (set in `didTapClaim`). The claim and the balance
    /// refresh are handled separately: once the server accepts the claim, the row must show
    /// "Claimed" even if the follow-up summary fetch fails, or the driver could try to claim twice.
    private func claim(_ incentive: DriverIncentive) async {
        defer { isClaimingIncentive = false }
        guard state.hasData else { return }
        actionErrorMessage = nil

        let updated: DriverIncentive
        do {
            let key = claimKeys[incentive.id] ?? UUID().uuidString
            claimKeys[incentive.id] = key
            updated = try await repository.claimIncentive(id: incentive.id, idempotencyKey: key)
            claimKeys[incentive.id] = nil
        } catch {
            // A definite refusal ends the action; an unknown outcome (network) keeps the key for the retry.
            if error is IncentiveError { claimKeys[incentive.id] = nil }
            logger.error("Failed to claim incentive: \(error.localizedDescription)")
            actionErrorMessage = String(localized: "Couldn't claim that reward. Please try again.")
            return
        }

        if var content = state.data, let index = content.incentives.firstIndex(where: { $0.id == updated.id }) {
            content.incentives[index] = updated
            state = .data(data: content)
        }

        do {
            let summary = try await repository.fetchSummary()
            if var content = state.data {
                content.summary = summary
                state = .data(data: content)
            }
        } catch {
            logger.error("Claimed incentive but failed to refresh balance: \(error.localizedDescription)")
            actionErrorMessage = String(localized: "Reward claimed, but we couldn't refresh your balance. Pull to reload.")
        }
    }
}

#if DEBUG

extension DriverEarningsDashboardViewModel {
    /// Preview-only: fixed state; load, claim and cash-out refresh do nothing. `isPreview` has no
    /// default because a bare `DriverEarningsDashboardViewModel()` would be ambiguous with the real init.
    /// `isEmptyView` is a loaded dashboard with no balance, history or incentives; `isClaiming` shows
    /// the claim in flight; `isClaimed` shows every incentive claimed.
    convenience init(
        isPreview: Bool,
        isLoading: Bool = false,
        isError: Bool = false,
        isEmptyView: Bool = false,
        isClaiming: Bool = false,
        isClaimed: Bool = false
    ) {
        self.init(repository: MockDriverEarningsRepository.shared)
        self.isPreview = isPreview
        if isLoading {
            state = .loading
        } else if isError {
            state = .error(message: "Couldn't load your earnings. Please try again.")
        } else if isEmptyView {
            state = .data(data: DriverEarningsDashboardContent(
                summary: .mock(availableBalance: 0, todayEarnings: 0, weekEarnings: 0, completedTripsToday: 0),
                history: [],
                incentives: []
            ))
        } else {
            var incentives = DriverIncentive.mockList()
            if isClaimed {
                incentives = incentives.map { incentive in
                    var claimed = incentive
                    claimed.status = .claimed
                    return claimed
                }
            }
            state = .data(data: DriverEarningsDashboardContent(
                summary: .mock(),
                history: CashOutRequest.mockList(),
                incentives: incentives
            ))
        }
        isClaimingIncentive = isClaiming
    }
}

#endif
