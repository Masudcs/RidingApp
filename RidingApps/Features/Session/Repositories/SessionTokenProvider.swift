import Foundation

/// `TokenProvider` backed by `SessionStore`. Refreshes with a plain `URLSession` call to
/// `POST auth/refresh` (not through `URLSessionAPIClient`, so a refresh can never trigger a refresh).
public final class SessionTokenProvider: TokenProvider {
    private struct RefreshBody: Encodable {
        let refreshToken: String
    }

    /// Tokens from a login that is not finished yet (role/profile steps still running), so those
    /// requests can already be authenticated. The session is only saved once sign-up completes.
    private static let pendingLock = NSLock()
    private static var pendingTokens: SessionTokens?

    /// Sets (or clears with nil) the in-memory tokens used while no session is saved.
    public static func setPendingTokens(_ tokens: SessionTokens?) {
        pendingLock.lock()
        pendingTokens = tokens
        pendingLock.unlock()
    }

    private static func loadPending() -> SessionTokens? {
        pendingLock.lock()
        defer { pendingLock.unlock() }
        return pendingTokens
    }

    /// Saved tokens first, otherwise the in-memory ones from an unfinished sign-up.
    private func activeTokens() -> SessionTokens? {
        store.loadTokens() ?? Self.loadPending()
    }

    private let baseURL: URL
    private let store: SessionStore
    private let session: URLSession
    private let coalescer = RefreshCoalescer()

    public init(baseURL: URL, store: SessionStore = SessionStore(), session: URLSession = .shared) {
        self.baseURL = baseURL
        self.store = store
        self.session = session
    }

    public func currentToken() async -> AccessToken? {
        guard let tokens = activeTokens() else { return nil }
        return AccessToken(token: tokens.accessToken, isExpired: tokens.isExpired)
    }

    public func refresh() async throws -> String {
        try await coalescer.run { [self] in try await performRefresh() }
    }

    private func performRefresh() async throws -> String {
        guard let refreshToken = activeTokens()?.refreshToken else { throw NetworkError.unauthorized }

        var request = URLRequest(url: baseURL.appendingPathComponent("auth/refresh"), timeoutInterval: 30)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RefreshBody(refreshToken: refreshToken))

        let data: Data
        let status: Int
        do {
            let (body, response) = try await session.data(for: request)
            data = body
            status = (response as? HTTPURLResponse)?.statusCode ?? -1
        } catch {
            throw NetworkError.transport(error.localizedDescription)
        }
        // The server says this refresh token is no good: the session is over.
        if status == 400 || status == 401 { throw NetworkError.unauthorized }
        guard (200..<300).contains(status) else { throw NetworkError.server(statusCode: status) }

        let payload: AuthTokensPayload
        do {
            payload = try JSONDecoder().decode(AuthTokensPayload.self, from: data)
        } catch {
            throw NetworkError.decoding(error.localizedDescription)
        }
        if !store.updateTokens(payload.tokens), Self.loadPending() != nil {
            Self.setPendingTokens(payload.tokens)
        }
        return payload.tokens.accessToken
    }
}
