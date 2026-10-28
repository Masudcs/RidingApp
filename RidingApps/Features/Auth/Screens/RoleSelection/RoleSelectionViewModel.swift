import Foundation
import Observation

/// Has no state of its own: each tap just reports the chosen role to `AuthFlowViewModel`.
@MainActor
@Observable
public final class RoleSelectionViewModel {
    @ObservationIgnored private let onSelectRole: (UserRole) -> Void

    public init(onSelectRole: @escaping (UserRole) -> Void) {
        self.onSelectRole = onSelectRole
    }

    public func didTapRider() {
        onSelectRole(.rider)
    }

    public func didTapDriver() {
        onSelectRole(.driver)
    }
}
