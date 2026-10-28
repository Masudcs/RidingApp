import Testing
import Foundation
@testable import RidingApps

@Test func vehicleTypeHasFourSeatsForCar() {
    #expect(VehicleType.car.capacity == 4)
}

@Test func moneyAdditionPreservesCurrency() {
    let total = Money.bdt(50) + Money.bdt(25.50)
    #expect(total.majorUnits == 75.5)
    #expect(total.currencyCode == "BDT")
}

@Test func localStoreRemoveAllForUserOnlyRemovesThatUsersKeys() {
    let suite = "test.localstore.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    LocalStore.save(["a"], forKey: "savedPlaces.user-1", defaults: defaults)
    LocalStore.save(5, forKey: "favoriteDrivers.blocked.user-1", defaults: defaults)
    LocalStore.save(["b"], forKey: "savedPlaces.user-2", defaults: defaults)

    let removed = LocalStore.removeAll(forUserId: "user-1", defaults: defaults)

    #expect(Set(removed) == ["savedPlaces.user-1", "favoriteDrivers.blocked.user-1"])
    #expect(defaults.object(forKey: "savedPlaces.user-1") == nil)
    #expect(defaults.object(forKey: "savedPlaces.user-2") != nil)
    #expect(LocalStore.removeAll(forUserId: "", defaults: defaults).isEmpty)
}

// MARK: - URLSessionAPIClient auth, refresh and headers

/// Routes requests of a stub `URLSession` to a per-host handler, so tests running in parallel don't interfere.
private final class StubURLProtocol: URLProtocol {
    typealias Handler = @Sendable (URLRequest) -> (status: Int, body: Data)
    private static let lock = NSLock()
    private static var handlers: [String: Handler] = [:]

    static func register(host: String, handler: @escaping Handler) {
        lock.withLock { handlers[host] = handler }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let handler = Self.lock.withLock { Self.handlers[request.url?.host ?? ""] }
        guard let handler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let (status, body) = handler(request)
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Thread-safe log of what the stub server saw.
private final class RequestLog: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [URLRequest] = []
    func add(_ request: URLRequest) { lock.withLock { items.append(request) } }
    var requests: [URLRequest] { lock.withLock { items } }
    var authHeaders: [String?] { requests.map { $0.value(forHTTPHeaderField: "Authorization") } }
}

/// Token provider double: counts refreshes, takes a moment to refresh so concurrent callers overlap.
private final class FakeTokenProvider: TokenProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var token: AccessToken?
    private var refreshes = 0
    private let refreshError: NetworkError?

    init(token: AccessToken?, refreshError: NetworkError? = nil) {
        self.token = token
        self.refreshError = refreshError
    }

    var refreshCount: Int { lock.withLock { refreshes } }

    func currentToken() async -> AccessToken? { lock.withLock { token } }

    func refresh() async throws -> String {
        lock.withLock { refreshes += 1 }
        try await Task.sleep(for: .milliseconds(100))
        if let refreshError { throw refreshError }
        lock.withLock { token = AccessToken(token: "new-token", isExpired: false) }
        return "new-token"
    }
}

private final class ExpiryCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func increment() { lock.withLock { value += 1 } }
    var count: Int { lock.withLock { value } }
}

private struct EmptyBody: Decodable {}

struct APIClientAuthTests {
    /// Stub server: 200 `{}` when the bearer token is `new-token`, otherwise 401. Always 401 if `rejectAll`.
    private func makeClient(
        provider: TokenProvider?,
        log: RequestLog,
        rejectAll: Bool = false,
        expired: ExpiryCounter = ExpiryCounter()
    ) -> URLSessionAPIClient {
        let host = "stub-\(UUID().uuidString).test"
        StubURLProtocol.register(host: host) { request in
            log.add(request)
            let ok = !rejectAll && request.value(forHTTPHeaderField: "Authorization") == "Bearer new-token"
            return (ok ? 200 : 401, Data("{}".utf8))
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSessionAPIClient(
            baseURL: URL(string: "https://\(host)")!,
            session: URLSession(configuration: configuration),
            tokenProvider: provider,
            onSessionExpired: { expired.increment() }
        )
    }

    @Test func concurrentRequestsWithExpiredTokenShareOneRefresh() async throws {
        let provider = FakeTokenProvider(token: AccessToken(token: "old", isExpired: true))
        let log = RequestLog()
        let client = makeClient(provider: provider, log: log)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    let _: EmptyBody = try await client.send(Endpoint(path: "ride"))
                }
            }
            try await group.waitForAll()
        }

        #expect(provider.refreshCount == 1)
        #expect(log.requests.count == 5)
        #expect(log.authHeaders.allSatisfy { $0 == "Bearer new-token" })
    }

    @Test func serverRejectionRefreshesOnceAndRetriesOnce() async throws {
        let provider = FakeTokenProvider(token: AccessToken(token: "old", isExpired: false))
        let log = RequestLog()
        let client = makeClient(provider: provider, log: log)

        let _: EmptyBody = try await client.send(Endpoint(path: "ride"))

        #expect(provider.refreshCount == 1)
        #expect(log.authHeaders == ["Bearer old", "Bearer new-token"])
    }

    @Test func concurrentRejectionsShareOneRefresh() async throws {
        let provider = FakeTokenProvider(token: AccessToken(token: "old", isExpired: false))
        let log = RequestLog()
        let client = makeClient(provider: provider, log: log)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<4 {
                group.addTask {
                    let _: EmptyBody = try await client.send(Endpoint(path: "ride"))
                }
            }
            try await group.waitForAll()
        }

        #expect(provider.refreshCount == 1)
    }

    @Test func rejectedRefreshThrowsUnauthorizedAndNotifiesWithoutRetry() async {
        let provider = FakeTokenProvider(token: AccessToken(token: "old", isExpired: false), refreshError: .unauthorized)
        let log = RequestLog()
        let expired = ExpiryCounter()
        let client = makeClient(provider: provider, log: log, expired: expired)

        await #expect(throws: NetworkError.unauthorized) {
            let _: EmptyBody = try await client.send(Endpoint(path: "ride"))
        }

        #expect(log.requests.count == 1)
        #expect(provider.refreshCount == 1)
        #expect(expired.count == 1)
    }

    @Test func stillRejectedAfterRefreshStopsAfterOneRetry() async {
        let provider = FakeTokenProvider(token: AccessToken(token: "old", isExpired: false))
        let log = RequestLog()
        let expired = ExpiryCounter()
        let client = makeClient(provider: provider, log: log, rejectAll: true, expired: expired)

        await #expect(throws: NetworkError.unauthorized) {
            let _: EmptyBody = try await client.send(Endpoint(path: "ride"))
        }

        #expect(log.requests.count == 2)
        #expect(provider.refreshCount == 1)
        #expect(expired.count == 1)
    }

    @Test func temporaryRefreshFailureDoesNotLogOut() async {
        let provider = FakeTokenProvider(token: AccessToken(token: "old", isExpired: true), refreshError: .transport("offline"))
        let log = RequestLog()
        let expired = ExpiryCounter()
        let client = makeClient(provider: provider, log: log, expired: expired)

        await #expect(throws: NetworkError.transport("offline")) {
            let _: EmptyBody = try await client.send(Endpoint(path: "ride"))
        }

        #expect(expired.count == 0)
        #expect(log.requests.isEmpty)
    }

    @Test func endpointsWithoutAuthSkipTokenAndRefresh() async {
        let provider = FakeTokenProvider(token: AccessToken(token: "old", isExpired: false))
        let log = RequestLog()
        let client = makeClient(provider: provider, log: log)

        await #expect(throws: NetworkError.server(statusCode: 401)) {
            let _: EmptyBody = try await client.send(Endpoint(path: "auth/otp/verify", method: .post, requiresAuth: false))
        }

        #expect(provider.refreshCount == 0)
        #expect(log.authHeaders == [nil])
    }

    @Test func sendsHeadersIdempotencyKeyAndTimeout() async throws {
        let provider = FakeTokenProvider(token: AccessToken(token: "new-token", isExpired: false))
        let log = RequestLog()
        let client = makeClient(provider: provider, log: log)

        let _: EmptyBody = try await client.send(Endpoint(
            path: "payments/charges",
            method: .post,
            body: Data("{}".utf8),
            headers: ["X-Test": "yes"],
            idempotencyKey: "key-123"
        ))

        let request = try #require(log.requests.first)
        #expect(request.value(forHTTPHeaderField: "Idempotency-Key") == "key-123")
        #expect(request.value(forHTTPHeaderField: "X-Test") == "yes")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer new-token")
        #expect(request.timeoutInterval == 30)
    }

    @Test func authTokensPayloadDecodesISO8601Dates() throws {
        let json = Data(#"{"accessToken":"a","refreshToken":"r","expiresAt":"2030-01-01T00:00:00Z"}"#.utf8)
        let payload = try JSONDecoder().decode(AuthTokensPayload.self, from: json)
        #expect(payload.tokens.accessToken == "a")
        #expect(payload.tokens.expiresAt == Date(timeIntervalSince1970: 1_893_456_000))
    }

    @Test func idempotencyKeyHolderReusesKeyUntilResetOrActionChanges() {
        var holder = IdempotencyKeyHolder()
        let first = holder.key(for: "100|bkash")
        #expect(holder.key(for: "100|bkash") == first)
        #expect(holder.key(for: "200|bkash") != first)
        let third = holder.key(for: "200|bkash")
        holder.reset()
        #expect(holder.key(for: "200|bkash") != third)
    }
}
