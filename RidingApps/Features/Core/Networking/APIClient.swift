import Foundation

/// HTTP verbs the app uses. Add `patch` here if the backend needs it.
public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

/// A request description (path relative to the base URL, method, query, JSON body). Built by
/// feature services and executed by an `APIClient`; the body is already-encoded JSON.
public struct Endpoint: Sendable {
    public let path: String
    public let method: HTTPMethod
    public let queryItems: [URLQueryItem]
    public let body: Data?
    /// Extra HTTP headers (e.g. `Accept-Language`). Applied before auth/idempotency headers.
    public let headers: [String: String]
    /// Sent as the `Idempotency-Key` header so the server can ignore a repeated money-moving call.
    /// One key per user action: reuse it when retrying, never per HTTP attempt.
    public let idempotencyKey: String?
    /// False for calls made before login (OTP, token refresh): no `Authorization` header and no refresh on 401.
    public let requiresAuth: Bool

    public init(
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        headers: [String: String] = [:],
        idempotencyKey: String? = nil,
        requiresAuth: Bool = true
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.body = body
        self.headers = headers
        self.idempotencyKey = idempotencyKey
        self.requiresAuth = requiresAuth
    }
}

/// Failures any `APIClient` can throw. `server` carries -1 when the response wasn't HTTP at all.
/// The messages are `localizedDescription` text, meant for logs, not for showing to users.
public enum NetworkError: Error, Equatable, Sendable {
    case invalidURL
    case transport(String)
    case decoding(String)
    case server(statusCode: Int)
    /// The session is no longer valid: the token could not be refreshed (or the server still said 401).
    case unauthorized
}

/// Thin abstraction over the transport layer so feature services can be unit tested and Dev/Staging
/// can run fully offline via `MockAPIClient` until the real backend exists.
public protocol APIClient: Sendable {
    func send<Response: Decodable>(_ endpoint: Endpoint) async throws -> Response
}

/// Real HTTP client used once `AppEnvironment.usesMockServices` is false.
///
/// Auth: when a `tokenProvider` is set, every request with `requiresAuth` carries
/// `Authorization: Bearer <token>`. An expired token is refreshed first; a 401 triggers one
/// refresh and one retry of the same request. Concurrent refreshes share one in-flight call.
/// If the refresh token is rejected the client throws `NetworkError.unauthorized` and calls
/// `onSessionExpired` (the app logs the user out). A refresh that fails for another reason
/// (offline, 5xx) is surfaced as is and does NOT log the user out.
///
/// Other known gaps: no retry beyond the one above, no mapping of error response bodies (any
/// non-2xx becomes `.server(statusCode:)`), and a plain `JSONDecoder` by default (pass a
/// configured decoder if the API uses ISO-8601 dates or snake_case). `Endpoint.path` is used
/// as already percent-encoded: ids interpolated into it must go through `String.pathEscaped`, and
/// query values belong in `Endpoint.queryItems`, not in the path.
public final class URLSessionAPIClient: APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let tokenProvider: TokenProvider?
    private let onSessionExpired: (@Sendable () -> Void)?
    private let requestTimeout: TimeInterval
    private let refreshCoalescer = RefreshCoalescer()

    /// - Parameters:
    ///   - session: injectable so tests can use a `URLProtocol` stub.
    ///   - tokenProvider: supplies/refreshes the access token; nil means unauthenticated requests.
    ///   - onSessionExpired: called when the session can no longer be refreshed.
    ///   - requestTimeout: per-request timeout in seconds.
    public init(
        baseURL: URL,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        tokenProvider: TokenProvider? = nil,
        onSessionExpired: (@Sendable () -> Void)? = nil,
        requestTimeout: TimeInterval = 30
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
        self.tokenProvider = tokenProvider
        self.onSessionExpired = onSessionExpired
        self.requestTimeout = requestTimeout
    }

    public func send<Response: Decodable>(_ endpoint: Endpoint) async throws -> Response {
        let request = try makeRequest(endpoint)
        let provider = endpoint.requiresAuth ? tokenProvider : nil

        var token: String?
        var didRefresh = false
        if let provider, let current = await provider.currentToken() {
            if current.isExpired {
                token = try await refreshedToken(replacing: current.token)
                didRefresh = true
            } else {
                token = current.token
            }
        }

        var (data, status) = try await perform(request, token: token)
        if status == 401, provider != nil {
            if didRefresh {
                // Already refreshed for this request and still rejected: stop, never loop.
                sessionExpired()
                throw NetworkError.unauthorized
            }
            let newToken = try await refreshedToken(replacing: token)
            (data, status) = try await perform(request, token: newToken)
            if status == 401 {
                sessionExpired()
                throw NetworkError.unauthorized
            }
        }

        guard (200..<300).contains(status) else { throw NetworkError.server(statusCode: status) }
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw NetworkError.decoding(error.localizedDescription)
        }
    }

    // MARK: - Private

    private func makeRequest(_ endpoint: Endpoint) throws -> URLRequest {
        // Set the path as already-encoded text. `appendingPathComponent` would encode the `%` of an
        // escaped id a second time (`a%2Fb` -> `a%252Fb`).
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        let basePath = components?.percentEncodedPath.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? ""
        let endpointPath = endpoint.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components?.percentEncodedPath = "/" + [basePath, endpointPath].filter { !$0.isEmpty }.joined(separator: "/")
        components?.queryItems = endpoint.queryItems.isEmpty ? nil : endpoint.queryItems
        guard let url = components?.url else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url, timeoutInterval: requestTimeout)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        if endpoint.body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        for (name, value) in endpoint.headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        if let key = endpoint.idempotencyKey {
            request.setValue(key, forHTTPHeaderField: "Idempotency-Key")
        }
        return request
    }

    /// Sends one HTTP attempt (adding the bearer token if any) and returns the body and status code.
    private func perform(_ request: URLRequest, token: String?) async throws -> (Data, Int) {
        var request = request
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, response) = try await session.data(for: request)
            return (data, (response as? HTTPURLResponse)?.statusCode ?? -1)
        } catch {
            throw NetworkError.transport(error.localizedDescription)
        }
    }

    /// Gets a usable token, sharing one refresh among concurrent callers. Skips the refresh if
    /// another caller already replaced `stale`. Notifies `onSessionExpired` when the refresh is rejected.
    private func refreshedToken(replacing stale: String?) async throws -> String {
        guard let provider = tokenProvider else { throw NetworkError.unauthorized }
        do {
            return try await refreshCoalescer.run {
                if let current = await provider.currentToken(), !current.isExpired, current.token != stale {
                    return current.token
                }
                return try await provider.refresh()
            }
        } catch NetworkError.unauthorized {
            sessionExpired()
            throw NetworkError.unauthorized
        }
    }

    private func sessionExpired() {
        onSessionExpired?()
    }
}
