import Foundation

/// Fake backend for development and tests: no network, short artificial delay.
/// Accepts any 4–6 digit code except "0000" (which simulates a wrong code).
public actor MockAuthRepository: IAuthRepository {
    private let logger = AppLogger(category: "Auth")

    public init() {}

    public func requestOTP(phoneNumber: String) async throws {
        await MockLatency.short()
        logger.info("Requested OTP for \(phoneNumber)")
    }

    public func verifyOTP(phoneNumber: String, code: String, role: UserRole) async throws -> AuthSession {
        await MockLatency.short()
        guard code.count >= 4, code.count <= 6, code.allSatisfy({ $0.isNumber }), code != "0000" else {
            logger.error("OTP verification failed for \(phoneNumber)")
            throw AuthError.invalidCode
        }
        logger.info("OTP verified for \(phoneNumber)")
        let user = AppUser(
            fullName: "New User",
            phoneNumber: phoneNumber,
            role: role
        )
        return AuthSession(user: user, tokens: Self.makeFakeTokens())
    }

    /// Random tokens that expire in 15 minutes, like a real login response.
    static func makeFakeTokens(now: Date = Date()) -> SessionTokens {
        SessionTokens(
            accessToken: "mock-access-" + UUID().uuidString,
            refreshToken: "mock-refresh-" + UUID().uuidString,
            expiresAt: now.addingTimeInterval(15 * 60)
        )
    }

    public func submitDriverVerification(_ verification: DriverVerification, for userId: String) async throws -> DriverVerification {
        await MockLatency.short()
        logger.info("Submitted driver verification for user \(userId)")
        var pending = verification
        pending.status = .pending
        return pending
    }

    /// Mock review always approves, so in Dev a new driver can reach the driver tabs without a
    /// real back office. (The real backend decides; it may also answer `.rejected`.)
    public func fetchDriverVerification(for userId: String, current: DriverVerification) async throws -> DriverVerification {
        await MockLatency.short()
        var approved = current
        if approved.status == .pending {
            approved.status = .verified
            approved.lastRecheckedAt = Date()
        }
        return approved
    }

    public func deleteAccount(userId: String) async throws {
        await MockLatency.short()
        logger.info("Deleted account for user \(userId)")
    }
}
