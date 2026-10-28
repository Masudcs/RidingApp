import Foundation

/// One place that builds real API clients with authentication wired in.
///
/// How other repositories get it: use `APIClientFactory.make()` as the default for their
/// `apiClient` init parameter instead of `URLSessionAPIClient(baseURL:)`, e.g.
/// `init(apiClient: APIClient = APIClientFactory.make())`. Mock repositories are unaffected.
public enum APIClientFactory {
    private static let lock = NSLock()
    private static var providers: [URL: SessionTokenProvider] = [:]
    private static var sessionExpiredHandler: (@Sendable () -> Void)?

    /// Builds a client for `baseURL` that sends the stored access token, refreshes it when needed
    /// and reports a dead session through the handler set by `setSessionExpiredHandler`.
    public static func make(baseURL: URL = AppEnvironment.current.apiBaseURL) -> APIClient {
        URLSessionAPIClient(
            baseURL: baseURL,
            tokenProvider: provider(for: baseURL),
            onSessionExpired: { notifySessionExpired() }
        )
    }

    /// Registers what happens when a refresh is rejected (the app signs the user out).
    public static func setSessionExpiredHandler(_ handler: (@Sendable () -> Void)?) {
        lock.lock()
        sessionExpiredHandler = handler
        lock.unlock()
    }

    private static func notifySessionExpired() {
        lock.lock()
        let handler = sessionExpiredHandler
        lock.unlock()
        handler?()
    }

    /// One provider per base URL, so every client shares the same refresh state.
    private static func provider(for baseURL: URL) -> SessionTokenProvider {
        lock.lock()
        defer { lock.unlock() }
        if let existing = providers[baseURL] { return existing }
        let created = SessionTokenProvider(baseURL: baseURL)
        providers[baseURL] = created
        return created
    }
}
