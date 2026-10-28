import Foundation
import Observation

/// Logic for the first auth step: the user types a phone number and we send them a one-time code.
/// On success it reports the cleaned-up number to `AuthFlowViewModel`, which moves to the OTP step.
@MainActor
@Observable
public final class PhoneEntryViewModel {
    /// Bound to the text field; may contain spaces, dashes, etc. as the user typed them.
    public var phoneNumber: String = ""
    public private(set) var isLoading: Bool = false
    /// Shown in an error banner; nil when there is nothing to show.
    public private(set) var errorMessage: String?

    @ObservationIgnored private let repository: IAuthRepository
    @ObservationIgnored private let onCodeSent: (String) -> Void
    @ObservationIgnored private let logger = AppLogger(category: "Auth")
    @ObservationIgnored private var isPreview = false

    /// Uses the mock repository or the real API depending on `AppEnvironment`.
    public init(
        initialPhoneNumber: String = "",
        repository: IAuthRepository = AuthRepositoryFactory.make(),
        onCodeSent: @escaping (String) -> Void
    ) {
        self.phoneNumber = initialPhoneNumber
        self.repository = repository
        self.onCodeSent = onCodeSent
    }

    /// Validates the number, asks the backend to send a code, then reports the number onward.
    public func didTapSendCode() {
        // Ignore taps while a request is already running (prevents sending two codes).
        guard !isLoading, !isPreview else { return }

        let number = Self.normalized(phoneNumber)
        guard Self.isValid(number) else {
            errorMessage = String(localized: "Please enter a valid phone number.")
            return
        }
        errorMessage = nil
        isLoading = true
        Task {
            do {
                try await repository.requestOTP(phoneNumber: number)
                isLoading = false
                onCodeSent(number)
            } catch {
                isLoading = false
                errorMessage = String(localized: "Could not send code. Please try again.")
                logger.error("sendOTP failed: \(error.localizedDescription)")
            }
        }
    }

    /// Removes spaces, dashes and brackets so "+880 1700-000000" becomes "+8801700000000".
    /// The backend then always receives one consistent format.
    static func normalized(_ raw: String) -> String {
        raw.filter { $0.isNumber || $0 == "+" }
    }

    /// Accepts 7–15 digits with an optional leading "+" (the international E.164 limits).
    /// This only catches obvious typos; the backend remains the real authority.
    static func isValid(_ number: String) -> Bool {
        let digits = number.hasPrefix("+") ? String(number.dropFirst()) : number
        return (7...15).contains(digits.count) && digits.allSatisfy(\.isNumber)
    }
}

#if DEBUG
extension PhoneEntryViewModel {
    /// Preview-only: fixed state, and taps never reach a repository.
    convenience init(
        isPreview: Bool,
        phoneNumber: String = "",
        isLoading: Bool = false,
        errorMessage: String? = nil
    ) {
        self.init(initialPhoneNumber: phoneNumber, repository: MockAuthRepository(), onCodeSent: { _ in })
        self.isPreview = isPreview
        self.isLoading = isLoading
        self.errorMessage = errorMessage
    }
}
#endif
