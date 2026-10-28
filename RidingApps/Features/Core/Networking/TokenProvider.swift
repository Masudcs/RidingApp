import Foundation

/// The access token the client should send, and whether it has already expired.
public struct AccessToken: Equatable, Sendable {
    public let token: String
    public let isExpired: Bool

    public init(token: String, isExpired: Bool) {
        self.token = token
        self.isExpired = isExpired
    }
}

/// Gives `URLSessionAPIClient` the current access token and a way to renew it.
public protocol TokenProvider: Sendable {
    /// The stored access token, or nil when nobody is signed in.
    func currentToken() async -> AccessToken?
    /// Gets and stores a new access token. Throws `NetworkError.unauthorized` when the refresh
    /// token is missing or rejected (the session is over); other errors are temporary.
    func refresh() async throws -> String
}

/// Runs an async job so that callers arriving while it is in flight share its result.
actor RefreshCoalescer {
    private var inFlight: Task<String, Error>?

    func run(_ work: @escaping @Sendable () async throws -> String) async throws -> String {
        if let inFlight { return try await inFlight.value }
        let task = Task { try await work() }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }
}

/// The `tokens` JSON object of auth responses: `{"accessToken", "refreshToken", "expiresAt"}`
/// where `expiresAt` is an ISO-8601 string. Decoded here so other repositories' date handling stays untouched.
public struct AuthTokensPayload: Decodable, Sendable {
    public let tokens: SessionTokens

    private enum CodingKeys: String, CodingKey {
        case accessToken, refreshToken, expiresAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let text = try container.decode(String.self, forKey: .expiresAt)
        guard let date = Self.parseDate(text) else {
            throw DecodingError.dataCorruptedError(forKey: .expiresAt, in: container, debugDescription: "Not an ISO-8601 date")
        }
        tokens = SessionTokens(
            accessToken: try container.decode(String.self, forKey: .accessToken),
            refreshToken: try container.decode(String.self, forKey: .refreshToken),
            expiresAt: date
        )
    }

    /// Accepts ISO-8601 with or without fractional seconds.
    static func parseDate(_ text: String) -> Date? {
        let plain = ISO8601DateFormatter()
        if let date = plain.date(from: text) { return date }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: text)
    }
}
