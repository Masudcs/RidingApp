import Foundation
import Observation

/// First step of the booking flow: remembers which vehicle type is highlighted (car by default).
@MainActor @Observable
public final class VehiclePickerViewModel {
    public private(set) var selectedVehicleType: VehicleType = .car

    @ObservationIgnored private let onContinue: (VehicleType) -> Void

    public init(onContinue: @escaping (VehicleType) -> Void) {
        self.onContinue = onContinue
    }

    public func didSelectVehicle(_ vehicleType: VehicleType) {
        selectedVehicleType = vehicleType
    }

    public func didTapContinue() {
        onContinue(selectedVehicleType)
    }
}

#if DEBUG

extension VehiclePickerViewModel {
    /// Preview state with a chosen vehicle highlighted.
    convenience init(isPreview: Bool = true, selected: VehicleType = .car) {
        self.init(onContinue: { _ in })
        selectedVehicleType = selected
    }
}

#endif
