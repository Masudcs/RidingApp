import Foundation

/// Plays the role of a backend over the same `APIClient` protocol a real `URLSessionAPIClient`
/// would use: each endpoint's business logic is registered as a handler that receives the raw
/// request and returns raw response data, so a feature service can go through a real
/// request/response round trip (including server-side state changes and typed errors) without a
/// live server. Swapping in a real backend later means constructing `URLSessionAPIClient` instead
/// — the `APIClient` protocol each feature service depends on doesn't change.
public final class MockAPIClient: APIClient, @unchecked Sendable {
    /// Receives the request and returns the JSON the server would send; throw `NetworkError` to simulate failures.
    public typealias Handler = @Sendable (Endpoint) async throws -> Data

    private let lock = NSLock()
    private var handlers: [String: Handler] = [:]

    public init() {}

    /// Registers (or replaces) the handler for an exact method + path match; query items are ignored in matching.
    public func register(_ method: HTTPMethod, _ path: String, handler: @escaping Handler) {
        lock.lock()
        handlers[key(method: method, path: path)] = handler
        lock.unlock()
    }

    public func send<Response: Decodable>(_ endpoint: Endpoint) async throws -> Response {
        await MockLatency.short()

        lock.lock()
        let handler = handlers[key(method: endpoint.method, path: endpoint.path)]
        lock.unlock()

        // Unregistered route behaves like a real 404.
        guard let handler else { throw NetworkError.server(statusCode: 404) }

        let data = try await handler(endpoint)
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw NetworkError.decoding(error.localizedDescription)
        }
    }

    private func key(method: HTTPMethod, path: String) -> String {
        "\(method.rawValue) \(path)"
    }
}
