import Foundation
import Observation

/// Controls the sign-up / login sequence. It only decides which step is current; each step's
/// screen owns its own ViewModel and reports back with plain values.
///
/// Order of steps:
///   phoneEntry -> otpEntry -> roleSelection -> profileDetails
///     -> rider:  done (authenticated)
///     -> driver: driverOnboarding -> done (authenticated)
///
/// When the flow finishes it calls `onAuthenticated` once, and `RootViewModel` takes over.
@MainActor
@Observable
public final class AuthFlowViewModel {
    /// The screen currently shown in the sign-up / login flow.
    public enum Step {
        case phoneEntry
        case otpEntry
        case roleSelection
        case profileDetails
        case driverOnboarding
        case done
    }

    public private(set) var step: Step = .phoneEntry
    /// Number entered in step 1, shown again on the OTP screen.
    public private(set) var phoneNumber: String = ""
    public private(set) var selectedRole: UserRole?
    /// Gender chosen on the profile step, kept so the screen is prefilled when the user comes back.
    public private(set) var profileGender: Gender?
    /// Women Safe Mode choice from the profile step, kept for the same reason.
    public private(set) var profileWomenSafeMode: Bool = false

    /// Called once when the user finishes the whole flow.
    @ObservationIgnored private let onAuthenticated: (AppUser, DriverVerification?, SessionTokens?) -> Void
    /// The user being built up step by step (id/phone from OTP, then role, then gender, ...).
    @ObservationIgnored private var authenticatedUser: AppUser?
    /// Tokens from the code check, handed on with the finished user.
    @ObservationIgnored private var sessionTokens: SessionTokens?
    @ObservationIgnored private var isPreview = false

    public init(onAuthenticated: @escaping (AppUser, DriverVerification?, SessionTokens?) -> Void) {
        self.onAuthenticated = onAuthenticated
    }

    public var currentUser: AppUser? { authenticatedUser }

    /// Step 1 finished: the code was sent.
    public func didSendCode(to phoneNumber: String) {
        self.phoneNumber = phoneNumber
        step = .otpEntry
    }

    /// Step 2 finished: the code was correct and the backend returned the user.
    /// - Parameter tokens: the API tokens from the same response (nil only in tests).
    public func didVerifyCode(user: AppUser, tokens: SessionTokens? = nil) {
        // Ignore a late result if the user already went back to change the number.
        guard step == .otpEntry else { return }
        authenticatedUser = user
        sessionTokens = tokens
        // Later sign-up requests (driver documents) need the token before the session is saved.
        SessionTokenProvider.setPendingTokens(tokens)
        step = .roleSelection
    }

    /// Step 3 finished: store the chosen role on the user being built.
    public func didSelectRole(_ role: UserRole) {
        guard step == .roleSelection, var user = authenticatedUser else { return }
        selectedRole = role
        user.role = role
        authenticatedUser = user
        step = .profileDetails
    }

    /// Step 4 finished. Riders are done here; drivers still need ID verification.
    public func didCompleteProfile(gender: Gender, womenSafeModeEnabled: Bool) {
        // Guard against a double tap finishing the flow (and calling onAuthenticated) twice.
        guard step == .profileDetails, var user = authenticatedUser else { return }
        profileGender = gender
        profileWomenSafeMode = womenSafeModeEnabled
        user.gender = gender
        // Women Safe Mode is a rider preference; drivers can never have it on.
        user.womenSafeModeEnabled = user.role == .rider ? womenSafeModeEnabled : false
        authenticatedUser = user

        switch user.role {
        case .rider:
            step = .done
            Analytics.track("auth_completed", ["role": user.role.rawValue])
            onAuthenticated(user, nil, sessionTokens)
        case .driver:
            step = .driverOnboarding
        }
    }

    /// Step 5 (drivers only) finished: documents were submitted, so the flow is complete.
    public func didSubmitDriverVerification(_ verification: DriverVerification) {
        guard step == .driverOnboarding, let user = authenticatedUser else { return }
        step = .done
        Analytics.track("auth_completed", ["role": user.role.rawValue])
        onAuthenticated(user, verification, sessionTokens)
    }

    /// True when a Back control makes sense: only before the flow is finished, and not on the
    /// first step or right after the code was verified (the account already exists then).
    public var canGoBack: Bool {
        switch step {
        case .otpEntry, .profileDetails, .driverOnboarding: return true
        case .phoneEntry, .roleSelection, .done: return false
        }
    }

    /// Moves one step back (code -> phone, profile -> role, driver documents -> profile).
    /// Entered values are kept in this view model. Does nothing on other steps.
    public func didTapBack() {
        switch step {
        case .otpEntry: step = .phoneEntry
        case .profileDetails: step = .roleSelection
        case .driverOnboarding: step = .profileDetails
        case .phoneEntry, .roleSelection, .done: break
        }
    }
}

#if DEBUG
extension AuthFlowViewModel {
    /// Preview-only: starts on `step` with the earlier steps' values filled in.
    convenience init(
        isPreview: Bool,
        step: Step,
        phoneNumber: String = "+8801700000000",
        role: UserRole = .rider,
        gender: Gender? = nil
    ) {
        self.init(onAuthenticated: { _, _, _ in })
        self.isPreview = isPreview
        self.step = step
        self.phoneNumber = phoneNumber
        self.profileGender = gender
        if step != .phoneEntry && step != .otpEntry {
            selectedRole = step == .roleSelection ? nil : role
            var user: AppUser = role == .driver ? .mockDriver() : .mockRider()
            user.role = role
            authenticatedUser = user
        }
    }

    /// True for flows built with the preview initializer; the screen then uses preview step screens.
    var isPreviewFlow: Bool { isPreview }
}
#endif
