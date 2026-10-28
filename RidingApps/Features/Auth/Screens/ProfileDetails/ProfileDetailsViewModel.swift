import Foundation
import Observation

/// Logic for the profile step. Gender is self-reported and must be chosen (one option is
/// "Prefer not to say"); it is never guessed.
@MainActor
@Observable
public final class ProfileDetailsViewModel {
    public private(set) var selectedGender: Gender?
    /// Bound to the toggle. Only meaningful for riders; `AuthFlowViewModel` forces it off for drivers.
    public var womenSafeModeEnabled: Bool = false
    public private(set) var errorMessage: String?

    @ObservationIgnored private let role: UserRole?
    @ObservationIgnored private let onContinue: (Gender, Bool) -> Void

    public init(
        role: UserRole?,
        initialGender: Gender? = nil,
        initialWomenSafeMode: Bool = false,
        onContinue: @escaping (Gender, Bool) -> Void
    ) {
        self.role = role
        self.selectedGender = initialGender
        self.womenSafeModeEnabled = initialWomenSafeMode
        self.onContinue = onContinue
    }

    /// The toggle is a rider preference, so drivers don't see it.
    public var showsWomenSafeMode: Bool { role == .rider }
    /// The Continue button stays disabled until a gender option is picked.
    public var canContinue: Bool { selectedGender != nil }

    public func didSelectGender(_ gender: Gender) {
        selectedGender = gender
    }

    public func didTapContinue() {
        guard let selectedGender else {
            errorMessage = String(localized: "Please select an option.")
            return
        }
        errorMessage = nil
        onContinue(selectedGender, womenSafeModeEnabled)
    }

    public func title(for gender: Gender) -> String {
        switch gender {
        case .female: return String(localized: "Female")
        case .male: return String(localized: "Male")
        case .undisclosed: return String(localized: "Prefer not to say")
        }
    }

    public func systemImage(for gender: Gender) -> String {
        switch gender {
        case .female: return "person.fill"
        case .male: return "person.fill"
        case .undisclosed: return "person.fill.questionmark"
        }
    }
}

#if DEBUG
extension ProfileDetailsViewModel {
    /// Preview-only: fixed state. This view model has no network calls, so no guard is needed.
    convenience init(
        isPreview: Bool,
        role: UserRole?,
        gender: Gender? = nil,
        womenSafeModeEnabled: Bool = false,
        errorMessage: String? = nil
    ) {
        self.init(role: role, initialGender: gender, initialWomenSafeMode: womenSafeModeEnabled, onContinue: { _, _ in })
        self.errorMessage = errorMessage
    }
}
#endif
