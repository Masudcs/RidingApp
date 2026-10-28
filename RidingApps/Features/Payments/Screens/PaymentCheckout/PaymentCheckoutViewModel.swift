import Foundation
import Observation

/// Drives the checkout shown right after a trip ends: fare breakdown, optional promo, tip and
/// fare split, then a single charge through `IPaymentsRepository`. When the charge succeeds it
/// shows the receipt for a moment and then calls `onPaymentCompleted` once, so the flow can move
/// on to rating.
///
/// All money is `Money` (integer minor units). The server is expected to recompute and verify the
/// final amount; what we send is what the rider saw on screen.
@MainActor
@Observable
public final class PaymentCheckoutViewModel {
    /// One line in the fare details card. The title doubles as the id, so titles must be unique.
    public struct FareRow: Identifiable {
        public let title: String
        public let amount: Money
        public var id: String { title }
    }

    /// Linked methods from the backend. Wallet and cash are always offered and are not in here.
    public var savedMethods: [PaymentMethodAccount] = []
    public var walletBalance: Money = .bdt(0)
    public var selectedMethod: PaymentMethodType = .cash
    /// True while the charge request is in flight. `didTapPay` ignores taps during this time.
    public var isProcessing: Bool = false
    /// Set once the charge succeeded. After this the screen hides the inputs and no further
    /// charge can be started.
    public var receipt: PaymentReceipt?
    public var errorMessage: String?

    public var promoCodeInput: String = ""
    public private(set) var appliedPromo: PromoCode?
    /// Discount from `appliedPromo`, already capped by the promo rules and the fare.
    public private(set) var discount: Money = Money(minorUnits: 0)
    public private(set) var isValidatingPromo = false
    public var promoErrorMessage: String?

    public var tipAmount: Money = Money(minorUnits: 0)
    /// Number of riders sharing the bill (including this rider). Only this rider's share is charged.
    public var splitCount: Int = 1

    /// Tip percentage the rider last tapped. The tip is a percentage of the discounted subtotal,
    /// so it has to be recalculated when a promo is applied or removed.
    @ObservationIgnored private var selectedTipPercentage: Double?

    public let tipPercentages: [Double] = [0.0, 0.10, 0.15, 0.20]
    public let splitRange = 1...6

    @ObservationIgnored private let trip: Trip
    @ObservationIgnored private let onPaymentCompleted: (PaymentReceipt) -> Void
    @ObservationIgnored private let repository: IPaymentsRepository
    /// Key for the current pay action; kept across failed attempts so a retry can't charge twice.
    @ObservationIgnored private var chargeKey = IdempotencyKeyHolder()
    @ObservationIgnored private let promoRepository: IPromoCodeRepository
    @ObservationIgnored private let logger = AppLogger(category: "Payments")
    @ObservationIgnored private var isPreview = false

    public init(
        trip: Trip,
        onPaymentCompleted: @escaping (PaymentReceipt) -> Void,
        repository: IPaymentsRepository = PaymentsRepository.makeDefault(),
        promoRepository: IPromoCodeRepository = PromoCodeRepository.makeDefault()
    ) {
        self.trip = trip
        self.onPaymentCompleted = onPaymentCompleted
        self.repository = repository
        self.promoRepository = promoRepository
    }

    // MARK: - Derived state

    /// Fare before promo, tip and split: the agreed fare if the rider negotiated one.
    private var originalAmount: Money {
        trip.agreedFare ?? trip.suggestedFare
    }

    /// Fare after the promo discount, before tip and split. Never below zero.
    public var subtotal: Money {
        Money(minorUnits: max(0, originalAmount.minorUnits - discount.minorUnits), currencyCode: originalAmount.currencyCode)
    }

    /// This rider's share of (subtotal + tip). Uses integer division, so with an uneven split
    /// the rounding remainder (less than `splitCount` minor units) is not charged to anyone.
    public var amountDue: Money {
        let total = subtotal + tipAmount
        return Money(minorUnits: total.minorUnits / max(1, splitCount), currencyCode: total.currencyCode)
    }

    public var amountTitle: String {
        splitCount > 1 ? String(localized: "Your Share") : String(localized: "Amount Due")
    }

    public var savedText: String? {
        discount.minorUnits > 0 ? "You saved \(discount.formatted)" : nil
    }

    public var splitSummary: String? {
        splitCount > 1 ? "Split \(splitCount) ways from \((subtotal + tipAmount).formatted) total" : nil
    }

    public var tipText: String? {
        tipAmount.minorUnits > 0 ? "Tip: \(tipAmount.formatted)" : nil
    }

    public var payButtonTitle: String {
        "Pay \(amountDue.formatted)"
    }

    public var canApplyPromo: Bool {
        !trimmedPromoInput.isEmpty && !isValidatingPromo && !isProcessing
    }

    private var trimmedPromoInput: String {
        promoCodeInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var fareRows: [FareRow] {
        let breakdown = FareBreakdown.compute(for: trip)
        var rows = [
            FareRow(title: "Base fare", amount: breakdown.baseFare),
            FareRow(title: String(format: "Distance (%.1f km)", breakdown.distanceKm), amount: breakdown.distanceFare)
        ]
        if breakdown.stopsFee.minorUnits > 0 {
            rows.append(FareRow(title: "Stops (\(trip.stops.count))", amount: breakdown.stopsFee))
        }
        if breakdown.surgeAmount.minorUnits > 0 {
            rows.append(FareRow(title: "Surge", amount: breakdown.surgeAmount))
        }
        return rows
    }

    /// Rows shown below the divider in the fare details disclosure.
    public var fareSummaryRows: [FareRow] {
        let breakdown = FareBreakdown.compute(for: trip)
        var rows = [FareRow(title: "Suggested fare", amount: breakdown.total)]
        if let agreedFare = trip.agreedFare, agreedFare != breakdown.total {
            rows.append(FareRow(title: "Negotiated fare", amount: agreedFare))
        }
        rows.append(FareRow(title: "Micro-insurance", amount: trip.insurancePremium))
        return rows
    }

    public func tipLabel(for percentage: Double) -> String {
        percentage == 0 ? "No tip" : "\(Int((percentage * 100).rounded()))%"
    }

    public func walletSubtitle() -> String {
        walletBalance.formatted
    }

    // MARK: - Actions

    /// Fetches saved methods and the wallet balance. Called when the screen appears. On failure
    /// the rider can still pay with cash or retry by reopening the screen.
    public func load() async {
        guard !isPreview else { return }
        do {
            async let methods = repository.fetchSavedMethods()
            async let balance = repository.fetchWalletBalance()
            savedMethods = try await methods
            walletBalance = try await balance
        } catch {
            // The view's .task is cancelled when the screen goes away; that isn't a failure to show.
            if Task.isCancelled { return }
            logger.error("Failed to load payment methods: \(error.localizedDescription)")
            errorMessage = String(localized: "Couldn't load payment methods. Please try again.")
        }
    }

    /// Sets the tip to `percentage` of the discounted subtotal (0 clears it).
    public func didTapTip(percentage: Double) {
        guard receipt == nil, !isProcessing else { return }
        selectedTipPercentage = percentage
        refreshTip()
    }

    private func refreshTip() {
        guard let percentage = selectedTipPercentage else { return }
        tipAmount = Money(minorUnits: Int((Double(subtotal.minorUnits) * percentage).rounded()), currencyCode: subtotal.currencyCode)
    }

    public func didSelectMethod(_ method: PaymentMethodType) {
        guard receipt == nil, !isProcessing else { return }
        selectedMethod = method
    }

    /// Validates the typed code against the fare and, if accepted, applies the discount.
    /// Ignored while another validation or the payment is running.
    public func didTapApplyPromo() async {
        guard !isPreview else { return }
        let code = trimmedPromoInput
        guard !code.isEmpty, !isValidatingPromo, !isProcessing, appliedPromo == nil else { return }
        let fareAmount = originalAmount
        isValidatingPromo = true
        promoErrorMessage = nil
        defer { isValidatingPromo = false }
        do {
            let promo = try await promoRepository.validate(code: code, fareAmount: fareAmount)
            // The rider may have started paying while we waited; don't change the amount under it.
            guard !isProcessing, receipt == nil else { return }
            appliedPromo = promo
            discount = promo.discount(on: fareAmount)
            refreshTip()
        } catch PromoCodeError.notFound {
            promoErrorMessage = String(localized: "That promo code isn't valid.")
        } catch PromoCodeError.belowMinimumFare(let minimum) {
            promoErrorMessage = "This code needs a fare of at least \(minimum.formatted)."
        } catch {
            promoErrorMessage = String(localized: "Couldn't apply that code. Please try again.")
        }
    }

    public func didTapRemovePromo() {
        guard receipt == nil, !isProcessing else { return }
        appliedPromo = nil
        discount = Money(minorUnits: 0)
        promoCodeInput = ""
        promoErrorMessage = nil
        refreshTip()
    }

    /// Charges this rider's share with the selected method. Ignored if a charge is already in
    /// flight or has already succeeded, so a double tap can't bill twice. All amounts are read
    /// once here, so edits made while the request runs don't change what was sent.
    public func didTapPay() async {
        guard !isPreview, !isProcessing, receipt == nil, !isValidatingPromo else { return }
        errorMessage = nil
        isProcessing = true
        defer { isProcessing = false }

        let fingerprint = "\(trip.id)|\(originalAmount.minorUnits)|\(selectedMethod.rawValue)|\(appliedPromo?.code ?? "")|\(discount.minorUnits)|\(tipAmount.minorUnits)|\(splitCount)"
        let key = chargeKey.key(for: fingerprint)
        do {
            let receipt = try await repository.charge(
                tripId: trip.id,
                amount: originalAmount,
                method: selectedMethod,
                promoCode: appliedPromo?.code,
                discount: discount,
                tip: tipAmount,
                splitCount: splitCount,
                idempotencyKey: key
            )
            chargeKey.reset()
            self.receipt = receipt
            Analytics.track("payment_completed", ["method": selectedMethod.rawValue])
            // Leave the success card up briefly before handing control back to the flow.
            Task { [onPaymentCompleted] in
                try? await Task.sleep(nanoseconds: 900_000_000)
                onPaymentCompleted(receipt)
            }
        } catch PaymentError.insufficientBalance {
            chargeKey.reset()
            errorMessage = String(localized: "Insufficient wallet balance. Please top up or choose another method.")
        } catch PaymentError.declined {
            chargeKey.reset()
            errorMessage = String(localized: "Payment was declined. Please try another method.")
        } catch {
            errorMessage = String(localized: "Something went wrong while processing your payment.")
        }
    }
}

#if DEBUG

extension PaymentCheckoutViewModel {
    /// Preview-only: fixed state; load, apply-promo and pay do nothing and never reach a repository.
    /// `isLoading` is the paying state (button spinner), `isEmptyView` is no saved methods and an
    /// empty wallet, `isError` is a declined payment. `promo`, `tipPercentage`, `splitCount` and
    /// `isPaid` set up the other checkout variants.
    convenience init(
        isPreview: Bool = true,
        isLoading: Bool = false,
        isError: Bool = false,
        isEmptyView: Bool = false,
        promo: PromoCode? = nil,
        tipPercentage: Double? = nil,
        splitCount: Int = 1,
        isPaid: Bool = false
    ) {
        self.init(
            trip: .mock(status: .completed),
            onPaymentCompleted: { _ in },
            repository: MockPaymentsRepository(),
            promoRepository: MockPromoCodeRepository()
        )
        self.isPreview = isPreview
        savedMethods = isEmptyView ? [] : PaymentMethodAccount.mockList()
        walletBalance = isEmptyView ? .bdt(0) : .bdt(500)
        selectedMethod = isEmptyView ? .cash : .wallet
        isProcessing = isLoading
        errorMessage = isError ? "Payment was declined. Please try another method." : nil
        if let promo {
            appliedPromo = promo
            discount = promo.discount(on: originalAmount)
        }
        self.splitCount = splitCount
        if let tipPercentage {
            selectedTipPercentage = tipPercentage
            refreshTip()
        }
        if isPaid {
            receipt = PaymentReceipt(
                id: "receipt-1",
                tripId: trip.id,
                method: selectedMethod,
                amount: amountDue,
                status: .captured,
                insurancePremium: trip.insurancePremium,
                promoCode: appliedPromo?.code,
                discountApplied: discount,
                tipAmount: tipAmount,
                splitCount: splitCount
            )
        }
    }
}

#endif
