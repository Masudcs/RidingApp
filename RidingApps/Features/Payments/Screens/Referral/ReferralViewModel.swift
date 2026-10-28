import Combine
import Foundation
import Observation

@MainActor
@Observable
/// Handles redeeming a friend's code through `ReferralStore`. `onRedeemed` is where the app adds the
/// bonus to the wallet; the success message is shown only after it finishes.
public final class ReferralViewModel {
    public var codeInput = ""
    public private(set) var errorMessage: String?
    public private(set) var successMessage: String?
    /// True from a valid redeem until `onRedeemed` has finished.
    public private(set) var isRedeeming = false
    public private(set) var creditEarned: Money

    @ObservationIgnored private let store: ReferralStore
    @ObservationIgnored private let onRedeemed: (Money) async -> Void
    @ObservationIgnored private var cancellable: AnyCancellable?
    @ObservationIgnored private var isPreview = false

    public init(store: ReferralStore, onRedeemed: @escaping (Money) async -> Void) {
        self.store = store
        self.onRedeemed = onRedeemed
        self.creditEarned = store.creditEarned
        cancellable = store.$creditEarned.sink { [weak self] in self?.creditEarned = $0 }
    }

    public var myCode: String { store.myCode }

    public var shareMessage: String {
        "Use my code \(store.myCode) on RidingApps \u{2014} we both get \(ReferralStore.referralBonus.formatted) credit!"
    }

    public var explanation: String {
        "Share this code \u{2014} you and your friend both get \(ReferralStore.referralBonus.formatted) wallet credit when they redeem it."
    }

    public var canRedeem: Bool {
        !codeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isRedeeming
    }

    public var hasEarnedCredit: Bool {
        creditEarned.minorUnits > 0
    }

    public func didTapRedeem() {
        guard !isPreview, !isRedeeming else { return }
        do {
            let bonus = try store.redeem(codeInput)
            codeInput = ""
            errorMessage = nil
            isRedeeming = true
            Task {
                await onRedeemed(bonus)
                successMessage = "You earned \(bonus.formatted)! It's been added to your balance."
                isRedeeming = false
            }
        } catch {
            successMessage = nil
            errorMessage = String(localized: "That code can't be redeemed.")
        }
    }
}

#if DEBUG

extension ReferralViewModel {
    /// Preview-only: fixed state, and `didTapRedeem` does nothing. `isLoading` is the redeeming state,
    /// `isEmptyView` is a rider with no earned credit.
    convenience init(isPreview: Bool = true, isLoading: Bool = false, isError: Bool = false, isEmptyView: Bool = false) {
        self.init(
            store: .mock(creditEarned: isEmptyView ? .bdt(0) : .bdt(100)),
            onRedeemed: { _ in }
        )
        self.isPreview = isPreview
        codeInput = isError ? "BADCODE" : ""
        isRedeeming = isLoading
        errorMessage = isError ? "That code can't be redeemed." : nil
        successMessage = (isLoading || isError || isEmptyView) ? nil : "You earned \(ReferralStore.referralBonus.formatted)! It's been added to your balance."
    }
}

#endif
