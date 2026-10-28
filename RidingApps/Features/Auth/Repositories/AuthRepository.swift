import Foundation

/// Real-backend implementation of `IAuthRepository`. Each method encodes a JSON body, posts it
/// through `APIClient`, and decodes the response.
public final class AuthRepository: IAuthRepository {
    /// Endpoint paths, relative to the API base URL.
    private enum Paths {
        static let requestOTP = "auth/otp/request"
        static let verifyOTP = "auth/otp/verify"
        static let driverVerification = "auth/driver-verification"
        static let account = "auth/account"
    }

    /// Body for `auth/otp/request`.
    private struct RequestOTPBody: Encodable {
        let phoneNumber: String
    }

    /// Body for `auth/otp/verify`.
    private struct VerifyOTPBody: Encodable {
        let phoneNumber: String
        let code: String
        let role: UserRole
    }

    /// Body for `auth/driver-verification`.
    private struct DriverVerificationBody: Encodable {
        let userId: String
        let verification: DriverVerification
    }

    /// Response of `auth/otp/verify`: `{"user": AppUser, "tokens": {accessToken, refreshToken, expiresAt}}`.
    private struct VerifyResponse: Decodable {
        let user: AppUser
        let tokens: AuthTokensPayload
    }

    /// For endpoints whose response body we don't need.
    private struct EmptyResponse: Decodable {}

    private let apiClient: APIClient

    public init(apiClient: APIClient = APIClientFactory.make()) {
        self.apiClient = apiClient
    }

    public func requestOTP(phoneNumber: String) async throws {
        let body = try JSONEncoder().encode(RequestOTPBody(phoneNumber: phoneNumber))
        let _: EmptyResponse = try await apiClient.send(Endpoint(path: Paths.requestOTP, method: .post, body: body, requiresAuth: false))
    }

    public func verifyOTP(phoneNumber: String, code: String, role: UserRole) async throws -> AuthSession {
        let body = try JSONEncoder().encode(VerifyOTPBody(phoneNumber: phoneNumber, code: code, role: role))
        do {
            let response: VerifyResponse = try await apiClient.send(
                Endpoint(path: Paths.verifyOTP, method: .post, body: body, requiresAuth: false)
            )
            return AuthSession(user: response.user, tokens: response.tokens.tokens)
        } catch NetworkError.server(let statusCode) where statusCode == 400 || statusCode == 401 {
            // The server rejected the code; map to a domain error the UI understands.
            throw AuthError.invalidCode
        }
    }

    public func submitDriverVerification(_ verification: DriverVerification, for userId: String) async throws -> DriverVerification {
        let body = try JSONEncoder().encode(DriverVerificationBody(userId: userId, verification: verification))
        return try await apiClient.send(Endpoint(path: Paths.driverVerification, method: .post, body: body))
    }

    public func fetchDriverVerification(for userId: String, current: DriverVerification) async throws -> DriverVerification {
        try await apiClient.send(Endpoint(
            path: Paths.driverVerification,
            method: .get,
            queryItems: [URLQueryItem(name: "userId", value: userId)]
        ))
    }

    public func deleteAccount(userId: String) async throws {
        let _: EmptyResponse = try await apiClient.send(Endpoint(
            path: Paths.account,
            method: .delete,
            queryItems: [URLQueryItem(name: "userId", value: userId)]
        ))
    }
}

/// Picks the auth backend in one place so every auth view model behaves the same.
public enum AuthRepositoryFactory {
    /// - A real server when `AUTH_API_BASE_URL` is set (see `AppEnvironment.authAPIBaseURL`), so the
    ///   verification code is really sent by SMS even while the rest of the app still uses mocks.
    /// - Otherwise the mock in Dev/Staging, and the production API in Production.
    public static func make() -> IAuthRepository {
        let environment = AppEnvironment.current
        if let url = environment.authAPIBaseURL {
            return AuthRepository(apiClient: APIClientFactory.make(baseURL: url))
        }
        return environment.usesMockServices ? MockAuthRepository() : AuthRepository()
    }
}
