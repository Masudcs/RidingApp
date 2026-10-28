import Foundation
import Observation

/// Backs the driver's "Cancel this trip?" sheet: collects a reason and reports it to the caller.
@MainActor @Observable
public final class DriverCancelTripViewModel {
    public var selectedReason: DriverCancellationReason = .riderNotAtPickup
    /// True from the confirm tap until the caller reports a failure; blocks a second confirm.
    public private(set) var isConfirming = false

    @ObservationIgnored private let onConfirm: (DriverCancellationReason) -> Void
    @ObservationIgnored private let onKeepTrip: () -> Void

    public init(onConfirm: @escaping (DriverCancellationReason) -> Void, onKeepTrip: @escaping () -> Void) {
        self.onConfirm = onConfirm
        self.onKeepTrip = onKeepTrip
    }

    public func didTapConfirm() {
        guard !isConfirming else { return }
        isConfirming = true
        onConfirm(selectedReason)
    }

    /// The caller could not cancel; lets the driver confirm again.
    public func didFailConfirmation() {
        isConfirming = false
    }

    public func didTapKeepTrip() {
        onKeepTrip()
    }
}

#if DEBUG

extension DriverCancelTripViewModel {
    /// Preview state. `isLoading` is the "confirm tapped, waiting for the caller" state.
    convenience init(isPreview: Bool = true, isLoading: Bool = false, reason: DriverCancellationReason = .riderNotAtPickup) {
        self.init(onConfirm: { _ in }, onKeepTrip: {})
        selectedReason = reason
        isConfirming = isLoading
    }
}

#endif
