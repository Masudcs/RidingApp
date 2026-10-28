import Foundation
import Observation

/// Logic for the second auth step: the user types the code that was sent to their phone.
/// On success it hands the verified `AuthSession` (user + tokens) to `AuthFlowViewModel`.
@MainActor
@Observable
public final class OTPEntryViewModel {
    /// Bound to the text field.
    public var otpCode: String = ""
    public private(set) var isLoading: Bool = false
    public private(set) var errorMessage: String?

    /// Seconds left before "Resend code" can be used again; 0 means it is available.
    public private(set) var resendSecondsRemaining: Int
    /// True while a resend request is running.
    public private(set) var isResending: Bool = false
    /// Inline result of the last resend ("sent" or "could not resend"); nil when nothing to show.
    public private(set) var resendMessage: String?
    /// True when `resendMessage` reports a failure (shown in the error colour).
    public private(set) var resendFailed: Bool = false

    /// The number the code was sent to (shown on screen and sent back with the code).
    public let phoneNumber: String

    @ObservationIgnored private let repository: IAuthRepository
    @ObservationIgnored private let onVerified: (AuthSession) -> Void
    @ObservationIgnored private let logger = AppLogger(category: "Auth")
    @ObservationIgnored private let resendCooldownSeconds: Int
    @ObservationIgnored private let tickInterval: Duration
    @ObservationIgnored private var cooldownTask: Task<Void, Never>?
    @ObservationIgnored private var resendTask: Task<Void, Never>?
    @ObservationIgnored private var isPreview = false

    /// - Parameters:
    ///   - resendCooldownSeconds: wait between codes (the dev server allows one per 30 s). Tests pass a small value.
    ///   - tickInterval: length of one countdown second; tests shorten it.
    public init(
        phoneNumber: String,
        repository: IAuthRepository = AuthRepositoryFactory.make(),
        resendCooldownSeconds: Int = 30,
        tickInterval: Duration = .seconds(1),
        onVerified: @escaping (AuthSession) -> Void
    ) {
        self.phoneNumber = phoneNumber
        self.repository = repository
        self.resendCooldownSeconds = resendCooldownSeconds
        self.tickInterval = tickInterval
        // A code was just sent to reach this screen, so start with the cooldown running.
        self.resendSecondsRemaining = resendCooldownSeconds
        self.onVerified = onVerified
    }

    /// True when "Resend code" may be tapped.
    public var canResend: Bool {
        resendSecondsRemaining == 0 && !isResending && !isLoading
    }

    /// Starts (or resumes) the countdown if time is left. Call when the screen appears.
    public func startCooldownIfNeeded() {
        guard !isPreview, resendSecondsRemaining > 0, cooldownTask == nil else { return }
        cooldownTask = Task { [weak self] in
            while let self, self.resendSecondsRemaining > 0 {
                try? await Task.sleep(for: self.tickInterval)
                if Task.isCancelled { return }
                self.resendSecondsRemaining -= 1
            }
            self?.cooldownTask = nil
        }
    }

    /// Stops the countdown and any resend request. Call when the screen disappears.
    public func cancelTasks() {
        cooldownTask?.cancel()
        cooldownTask = nil
        resendTask?.cancel()
        resendTask = nil
        isResending = false
    }

    /// Asks the backend for a new code and clears the typed one. Ignored during the cooldown or
    /// while another request is running. Any failure (offline, 429 rate limit) shows the same message.
    public func didTapResend() {
        guard canResend, !isPreview else { return }
        isResending = true
        resendMessage = nil
        resendFailed = false
        errorMessage = nil
        otpCode = ""
        resendTask = Task {
            do {
                try await repository.requestOTP(phoneNumber: phoneNumber)
                guard !Task.isCancelled else { return }
                resendMessage = String(localized: "A new code was sent.")
            } catch {
                guard !Task.isCancelled else { return }
                resendFailed = true
                resendMessage = String(localized: "Could not resend the code.")
                logger.error("resend OTP failed: \(error.localizedDescription)")
            }
            isResending = false
            resendTask = nil
            // Wait before the next try either way; after a 429 the server needs the time too.
            resendSecondsRemaining = resendCooldownSeconds
            cooldownTask = nil
            startCooldownIfNeeded()
        }
    }

    /// Checks the code with the backend and, if correct, moves the flow forward.
    public func didTapVerify() {
        // Ignore taps while a request is already running.
        guard !isLoading, !isPreview else { return }

        let code = otpCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            errorMessage = String(localized: "Please enter the verification code.")
            return
        }
        errorMessage = nil
        resendMessage = nil
        isLoading = true
        Task {
            do {
                // The role isn't chosen yet (that's the next step), so `.rider` is only a
                // placeholder; `AuthFlowViewModel.didSelectRole` sets the real role afterwards.
                // TODO(real API): don't send a role here; send it when the profile is saved.
                let session = try await repository.verifyOTP(
                    phoneNumber: phoneNumber,
                    code: code,
                    role: .rider
                )
                isLoading = false
                onVerified(session)
            } catch AuthError.invalidCode {
                // The user typed the wrong code: they can retry.
                isLoading = false
                errorMessage = String(localized: "Invalid code. Please try again.")
            } catch {
                // Anything else (no internet, server down) is not the user's mistake,
                // so don't tell them the code is wrong.
                isLoading = false
                errorMessage = String(localized: "Could not verify the code. Check your connection and try again.")
                logger.error("verifyOTP failed: \(error.localizedDescription)")
            }
        }
    }
}

#if DEBUG
extension OTPEntryViewModel {
    /// Preview-only: fixed state; no countdown starts and taps never reach a repository.
    convenience init(
        isPreview: Bool,
        phoneNumber: String = "+8801700000000",
        otpCode: String = "",
        isLoading: Bool = false,
        errorMessage: String? = nil,
        resendSecondsRemaining: Int = 0,
        resendMessage: String? = nil,
        resendFailed: Bool = false
    ) {
        self.init(phoneNumber: phoneNumber, repository: MockAuthRepository(), onVerified: { _ in })
        self.isPreview = isPreview
        self.otpCode = otpCode
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.resendSecondsRemaining = resendSecondsRemaining
        self.resendMessage = resendMessage
        self.resendFailed = resendFailed
    }
}
#endif
