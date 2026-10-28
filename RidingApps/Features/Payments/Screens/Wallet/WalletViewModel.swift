import Foundation
import Observation

/// Drives the Wallet tab: balance, adding money from a linked method, linking new methods and the
/// recent payments list. Each action ignores repeat taps while its request is running, because
/// both top-ups and links change real account state.
@MainActor
@Observable
public final class WalletViewModel {
    public var balance: Money = .bdt(0)
    public var savedMethods: [PaymentMethodAccount] = []
    public var history: [PaymentReceipt] = []
    /// True while `load()` is running.
    public var isLoading: Bool = false
    /// Last failure from any wallet action, shown in a banner. Cleared when the next action starts.
    public var errorMessage: String?

    public var newMethodType: PaymentMethodType = .bKash
    public var newMethodIdentifier: String = ""

    /// Raw text from the amount field, in taka. Parsed in `didTapTopUp`.
    public var topUpAmountInput: String = ""
    public var topUpMethod: PaymentMethodType = .bKash
    public private(set) var isToppingUp = false
    /// True while a link request is running; blocks a second tap from linking twice.
    public private(set) var isLinkingMethod = false

    @ObservationIgnored private let repository: IPaymentsRepository
    /// Key for the current top-up action; kept across failed attempts so a retry can't add money twice.
    @ObservationIgnored private var topUpKey = IdempotencyKeyHolder()
    @ObservationIgnored private let logger = AppLogger(category: "Payments")
    @ObservationIgnored private var isPreview = false

    public init(repository: IPaymentsRepository = PaymentsRepository.makeDefault()) {
        self.repository = repository
    }

    /// Quick-pick top-up amounts in whole taka.
    public let topUpPresets = [100, 200, 500, 1000]
    /// Cash and wallet can't be linked or used to fund the wallet.
    public let linkableMethods = PaymentMethodType.allCases.filter { $0 != .cash && $0 != .wallet }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    public var canTopUp: Bool {
        !topUpAmountInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isToppingUp
    }

    /// Upper bound for one top-up (in taka). Also keeps the minor-unit conversion far from overflow.
    private static let maxTopUpTaka = 100_000

    /// Parses the amount field as an exact decimal in the user's locale (decimal pad can type "," in
    /// some locales). Returns nil for empty, non-numeric, zero/negative, over-limit, or more than
    /// two decimal places. Avoids `Double` so "inf", "1e9" or 0.1 + 0.2 style errors can't get through.
    private func parsedTopUpAmount() -> Money? {
        let text = topUpAmountInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.generatesDecimalNumbers = true
        guard let number = formatter.number(from: text) as? NSDecimalNumber,
              number != NSDecimalNumber.notANumber else { return nil }
        let taka = number.decimalValue
        guard taka > 0, taka <= Decimal(Self.maxTopUpTaka) else { return nil }
        var minor = taka * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &minor, 0, .plain)
        guard rounded == minor else { return nil }
        return Money(minorUnits: NSDecimalNumber(decimal: rounded).intValue)
    }

    public func dateText(for receipt: PaymentReceipt) -> String {
        Self.dateFormatter.string(from: receipt.createdAt)
    }

    public func didTapPreset(_ preset: Int) {
        topUpAmountInput = String(preset)
    }

    /// Fetches balance, methods and history together. Called when the tab appears. If any of the
    /// three fails nothing is updated and an error is shown, so the screen never mixes new and
    /// stale data.
    public func load() async {
        guard !isPreview, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let balanceResult = repository.fetchWalletBalance()
            async let methodsResult = repository.fetchSavedMethods()
            async let historyResult = repository.paymentHistory()
            let (newBalance, newMethods, newHistory) = try await (balanceResult, methodsResult, historyResult)
            balance = newBalance
            savedMethods = newMethods
            history = newHistory
            errorMessage = nil
        } catch {
            // The view's .task is cancelled when the tab goes away; that isn't a failure to show.
            if Task.isCancelled { return }
            logger.error("Failed to load wallet: \(error.localizedDescription)")
            errorMessage = String(localized: "Couldn't load your wallet. Please try again.")
        }
    }

    /// Adds the typed amount to the wallet from `topUpMethod`. The balance shown is the one the
    /// backend returns, not a local sum. On failure the amount stays in the field for a retry;
    /// note a network error does not prove the top-up didn't happen, so the balance is refreshed.
    public func didTapTopUp() async {
        guard !isPreview, !isToppingUp else { return }
        errorMessage = nil
        guard let amount = parsedTopUpAmount() else {
            errorMessage = String(localized: "Enter a valid amount to add.")
            return
        }

        isToppingUp = true
        defer { isToppingUp = false }
        do {
            let key = topUpKey.key(for: "\(amount.minorUnits)|\(topUpMethod.rawValue)")
            balance = try await repository.topUp(amount: amount, method: topUpMethod, idempotencyKey: key)
            topUpKey.reset()
            topUpAmountInput = ""
        } catch PaymentError.declined {
            // A definite refusal ends this action; the next try is a new one.
            topUpKey.reset()
            logger.error("Top-up declined")
            errorMessage = String(localized: "Couldn't add money right now. Please try again.")
        } catch {
            logger.error("Failed to top up wallet: \(error.localizedDescription)")
            errorMessage = String(localized: "Couldn't add money right now. Please try again.")
            // The request may have reached the server before failing; show the real balance.
            if let current = try? await repository.fetchWalletBalance() {
                balance = current
            }
        }
    }

    /// Links `newMethodIdentifier` as a new `newMethodType` account and adds it to the list.
    public func didTapLinkMethod() async {
        guard !isPreview, !isLinkingMethod else { return }
        errorMessage = nil
        let identifier = newMethodIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identifier.isEmpty else {
            errorMessage = String(localized: "Please enter an account number or card identifier.")
            return
        }

        isLinkingMethod = true
        defer { isLinkingMethod = false }
        do {
            let account = try await repository.linkMethod(type: newMethodType, identifier: identifier)
            savedMethods.append(account)
            newMethodIdentifier = ""
        } catch {
            logger.error("Failed to link method: \(error.localizedDescription)")
            errorMessage = String(localized: "Couldn't link that payment method. Please try again.")
        }
    }
}

#if DEBUG

extension WalletViewModel {
    /// Preview-only: fixed state, and load/top-up/link do nothing. `isLoading` and `isEmptyView` both
    /// show a wallet with no data yet; `isError` adds the failed top-up banner; `isToppingUp` is the
    /// Add Money button mid-request.
    convenience init(
        isPreview: Bool = true,
        isLoading: Bool = false,
        isError: Bool = false,
        isEmptyView: Bool = false,
        isToppingUp: Bool = false
    ) {
        self.init(repository: MockPaymentsRepository())
        self.isPreview = isPreview
        self.isLoading = isLoading
        errorMessage = isError ? "Couldn't add money right now. Please try again." : nil
        if !isLoading && !isEmptyView {
            balance = .bdt(500)
            savedMethods = PaymentMethodAccount.mockList()
            history = [
                .mock(method: .wallet),
                PaymentReceipt(
                    id: "receipt-2",
                    tripId: "trip-2",
                    method: .bKash,
                    amount: .bdt(180),
                    status: .captured,
                    createdAt: Date().addingTimeInterval(-86_400)
                )
            ]
        }
        if isError || isToppingUp {
            topUpAmountInput = "500"
        }
        self.isToppingUp = isToppingUp
    }
}

#endif
