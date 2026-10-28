import Foundation
import Observation

/// Backs the rider's "Cancel this ride?" sheet. It only collects the reason and reports the fee the
/// rider was shown; the caller does the actual cancel request.
@MainActor @Observable
public final class CancellationViewModel {
    public var selectedReason: CancellationReason = .changedMyMind
    /// True from the confirm tap until the caller reports a failure; blocks a second confirm.
    public private(set) var isConfirming = false

    @ObservationIgnored private let trip: Trip
    @ObservationIgnored private let onConfirm: (CancellationReason, Money) -> Void
    @ObservationIgnored private let onKeepRide: () -> Void

    public init(trip: Trip, onConfirm: @escaping (CancellationReason, Money) -> Void, onKeepRide: @escaping () -> Void) {
        self.trip = trip
        self.onConfirm = onConfirm
        self.onKeepRide = onKeepRide
    }

    /// Recomputed on every read because the free window runs out while the sheet is open.
    public var quote: CancellationQuote {
        CancellationPolicy.quote(for: trip)
    }

    public var confirmTitle: String {
        quote.isFree ? String(localized: "Confirm cancellation") : String(localized: "Cancel and pay \(quote.fee.formatted)")
    }

    /// Passes the fee from the quote at tap time, so the rider is charged what the button said.
    public func didTapConfirm() {
        guard !isConfirming else { return }
        isConfirming = true
        onConfirm(selectedReason, quote.fee)
    }

    /// The caller could not cancel; lets the rider confirm again.
    public func didFailConfirmation() {
        isConfirming = false
    }

    public func didTapKeepRide() {
        onKeepRide()
    }
}

#if DEBUG

extension CancellationViewModel {
    /// Preview state. `isLoading` is the "confirm tapped, waiting for the caller" state.
    convenience init(isPreview: Bool = true, trip: Trip = .mock(status: .searchingDriver), isLoading: Bool = false, reason: CancellationReason = .changedMyMind) {
        self.init(trip: trip, onConfirm: { _, _ in }, onKeepRide: {})
        selectedReason = reason
        isConfirming = isLoading
    }
}

#endif
