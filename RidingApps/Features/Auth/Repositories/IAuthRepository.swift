import Foundation

/// Result of a successful code check: the account plus the API tokens for later requests.
public struct AuthSession: Equatable, Sendable {
    public let user: AppUser
    public let tokens: SessionTokens

    public init(user: AppUser, tokens: SessionTokens) {
        self.user = user
        self.tokens = tokens
    }
}

/// What the auth screens need from a backend. Implemented by `AuthRepository` (real API) and
/// `MockAuthRepository` (fake data); view models choose via `AppEnvironment.usesMockServices`.
public protocol IAuthRepository: Sendable {
    /// Sends a one-time code by SMS to the phone number.
    func requestOTP(phoneNumber: String) async throws
    /// Checks the code and returns the user with the API tokens. Throws `AuthError.invalidCode` if it is wrong.
    func verifyOTP(phoneNumber: String, code: String, role: UserRole) async throws -> AuthSession
    /// Uploads driver ID/vehicle details; the returned verification has status `.pending`.
    func submitDriverVerification(_ verification: DriverVerification, for userId: String) async throws -> DriverVerification
    /// Asks the backend for the driver's current review status (pending -> verified or rejected).
    /// - Parameter current: the record the app already has. The real backend ignores it and answers
    ///   from its own data; the mock uses it to build an "approved" copy.
    func fetchDriverVerification(for userId: String, current: DriverVerification) async throws -> DriverVerification
    /// Permanently deletes the account and its server-side data (App Store requirement).
    /// Throws if the server could not delete it; the caller must then keep the user signed in.
    func deleteAccount(userId: String) async throws
}
