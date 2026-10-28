import Observation
import Foundation

/// Drives the cash-out sheet: validates the typed amount, submits one request at a time, and
/// reports the result. On success it calls `onCashedOut` so the dashboard can refresh its balance.
@MainActor
@Observable
public final class CashOutViewModel {
    /// Raw text of the amount field, in the user's locale (e.g. "1,250.50").
    public var amountText: String = ""
    public var selectedDestination: PaymentMethodType = .bKash
    /// True from the moment a request is accepted for submission until it finishes. Used to block
    /// duplicate taps, so it is set synchronously before the network call starts.
    public private(set) var isCashingOut: Bool = false
    public private(set) var errorMessage: String?
    /// The most recent settled request; cleared when a new attempt starts.
    public private(set) var lastCashOut: CashOutRequest?

    /// Balance the dashboard had when the sheet opened. Only used for "Cash out all"; the server
    /// stays the source of truth and re-checks the amount.
    private let availableBalance: Money?
    @ObservationIgnored private let repository: IDriverEarningsRepository
    @ObservationIgnored private let onCashedOut: () -> Void
    /// Key for the current cash-out action; kept across failed attempts so a retry can't pay out twice.
    @ObservationIgnored private var cashOutKey = IdempotencyKeyHolder()
    @ObservationIgnored private let logger = AppLogger(category: "CashOutViewModel")
    @ObservationIgnored private var isPreview = false

    /// Upper bound on a typed amount (in taka). Stops absurd input from overflowing the paisa `Int`.
    private static let maximumTaka: Decimal = 100_000_000

    public init(
        availableBalance: Money?,
        repository: IDriverEarningsRepository = AppEnvironment.current.usesMockServices ? MockDriverEarningsRepository.shared : DriverEarningsRepository(),
        onCashedOut: @escaping () -> Void = {}
    ) {
        self.availableBalance = availableBalance
        self.repository = repository
        self.onCashedOut = onCashedOut
    }

    public func didTapCashOut() {
        guard !isPreview else { return }
        guard !isCashingOut else { return }
        guard let amount = Self.parseAmount(amountText) else {
            errorMessage = String(localized: "Enter a valid amount to cash out.")
            return
        }
        submit(amount)
    }

    /// Fills the field with the whole balance and submits it right away.
    public func didTapCashOutAll() {
        guard !isPreview else { return }
        guard !isCashingOut, let availableBalance else { return }
        amountText = String(format: "%.2f", availableBalance.majorUnits)
        guard availableBalance.minorUnits > 0 else {
            errorMessage = String(localized: "Enter a valid amount to cash out.")
            return
        }
        // Use the exact balance instead of re-parsing the text, so no rounding can creep in.
        submit(availableBalance)
    }

    public func didSelectDestination(_ method: PaymentMethodType) {
        guard !isCashingOut else { return }
        selectedDestination = method
    }

    /// Marks the request as in flight immediately (before the Task runs) so a second tap cannot
    /// start a second request. The Task is not cancelled if the sheet closes: the money may already
    /// have moved, so the result must still reach `onCashedOut`.
    private func submit(_ amount: Money) {
        isCashingOut = true
        errorMessage = nil
        lastCashOut = nil
        let destination = selectedDestination
        Task { await cashOut(amount: amount, destination: destination) }
    }

    private func cashOut(amount: Money, destination: PaymentMethodType) async {
        defer { isCashingOut = false }
        do {
            let key = cashOutKey.key(for: "\(amount.minorUnits)|\(destination.rawValue)")
            let request = try await repository.requestCashOut(amount: amount, destination: destination, idempotencyKey: key)
            cashOutKey.reset()
            lastCashOut = request
            amountText = ""
            onCashedOut()
        } catch let error as CashOutError {
            cashOutKey.reset()
            errorMessage = friendlyMessage(for: error)
        } catch {
            logger.error("Cash-out failed: \(error.localizedDescription)")
            errorMessage = String(localized: "Cash-out failed. Please try again.")
        }
    }

    /// Turns user-typed text into money. Returns nil for empty, non-numeric, zero, negative,
    /// NaN/infinite, over-limit, or more-than-2-decimal input. Uses `Decimal`, not `Double`, so
    /// "0.29" never becomes 28 paisa.
    static func parseAmount(_ text: String, locale: Locale = .current) -> Money? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.generatesDecimalNumbers = true
        formatter.isLenient = false
        guard let number = formatter.number(from: trimmed) as? NSDecimalNumber else { return nil }

        let taka = number.decimalValue
        guard !taka.isNaN, taka > 0, taka <= maximumTaka else { return nil }

        var paisa = taka * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &paisa, 0, .plain)
        // Reject sub-paisa input like "10.005" instead of silently rounding someone's money.
        guard rounded == paisa else { return nil }

        return Money(minorUnits: NSDecimalNumber(decimal: rounded).intValue)
    }

    private func friendlyMessage(for error: CashOutError) -> String {
        switch error {
        case .exceedsAvailableBalance:
            return String(localized: "That amount exceeds your available balance.")
        case .belowMinimum:
            return String(localized: "Minimum cash-out amount is \u{09F3} 50.00.")
        }
    }
}

#if DEBUG

extension CashOutViewModel {
    /// Preview-only: fixed state, and the cash-out buttons do nothing, so nothing reaches a repository.
    /// `isInvalidAmount` and `isFailure` show an error banner; `isSuccess` shows the settled confirmation.
    convenience init(
        isPreview: Bool = true,
        hasAmount: Bool = false,
        isInvalidAmount: Bool = false,
        isCashingOut: Bool = false,
        isSuccess: Bool = false,
        isFailure: Bool = false
    ) {
        self.init(availableBalance: .bdt(2_450), repository: MockDriverEarningsRepository.shared)
        self.isPreview = isPreview
        if isInvalidAmount {
            amountText = "abc"
            errorMessage = "Enter a valid amount to cash out."
        } else if hasAmount || isCashingOut || isFailure {
            amountText = "1000.00"
        }
        self.isCashingOut = isCashingOut
        if isFailure {
            errorMessage = "Cash-out failed. Please try again."
        }
        if isSuccess {
            lastCashOut = .mock(taka: 1_000, destination: .bKash, status: .settled, hoursAgo: 0)
        }
    }
}

#endif
