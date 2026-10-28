import Foundation
import Observation

/// Owns only the navigation of the booking flow; each step's own state lives in that step's
/// ViewModel and is handed on as plain values.
///
/// Steps: vehicle picker (the stack root, not in `path`) -> `.location` -> `.negotiation`.
@MainActor @Observable
public final class BookingFlowViewModel {
    /// A screen pushed onto the booking `NavigationStack`, carrying what it needs.
    public enum Step: Hashable {
        /// Pickup / stops / dropoff, for the chosen vehicle.
        case location(VehicleType)
        /// Fare estimate and negotiation (or scheduling) for the chosen route.
        case negotiation(RideRequestDraft)
    }

    /// Bound to the `NavigationStack`; the root vehicle picker is not part of it.
    public var path: [Step] = []
    /// Presents the scheduled rides list as a sheet.
    public var showScheduledRides = false

    public init() {}

    public func didTapScheduledRides() {
        showScheduledRides = true
    }

    public func didContinueFromVehicle(_ vehicleType: VehicleType) {
        // Ignore a double tap that would push the location step twice.
        guard path.isEmpty else { return }
        path.append(.location(vehicleType))
    }

    public func didContinueFromLocation(_ draft: RideRequestDraft) {
        // Only valid while the location step is on top; ignores a double tap on a dropoff row.
        guard case .location = path.last else { return }
        path.append(.negotiation(draft))
    }

    /// A scheduled ride was saved: go back to the vehicle picker.
    public func didConfirmScheduledRide() {
        path = []
    }

    /// A scheduled ride was started from the list: close the sheet.
    public func didStartScheduledRide() {
        showScheduledRides = false
    }
}

#if DEBUG

extension BookingFlowViewModel {
    /// Preview state: a pushed step and/or the scheduled rides sheet already showing.
    convenience init(isPreview: Bool = true, path: [Step], showScheduledRides: Bool = false) {
        self.init()
        self.path = path
        self.showScheduledRides = showScheduledRides
    }
}

#endif
