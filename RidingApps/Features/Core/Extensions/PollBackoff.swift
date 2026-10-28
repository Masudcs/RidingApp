import Foundation

/// Retry timing for a polling loop: the delay doubles after each failure up to a cap and resets on success.
public struct PollBackoff: Sendable, Equatable {
    /// Normal delay between polls, and the first delay after a failure.
    public let baseDelay: Duration
    /// The delay never grows past this.
    public let maxDelay: Duration
    /// Consecutive failures before the connection counts as a problem.
    public let failureThreshold: Int
    public private(set) var consecutiveFailures = 0

    public init(baseDelay: Duration = .seconds(2), maxDelay: Duration = .seconds(30), failureThreshold: Int = 3) {
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.failureThreshold = failureThreshold
    }

    /// True once `failureThreshold` polls in a row have failed.
    public var hasConnectionProblem: Bool {
        consecutiveFailures >= failureThreshold
    }

    /// How long to wait before the next poll.
    public var currentDelay: Duration {
        guard consecutiveFailures > 0 else { return baseDelay }
        var delay = baseDelay
        for _ in 1..<consecutiveFailures {
            delay *= 2
            if delay >= maxDelay { return maxDelay }
        }
        return min(delay, maxDelay)
    }

    public mutating func recordSuccess() {
        consecutiveFailures = 0
    }

    public mutating func recordFailure() {
        consecutiveFailures += 1
    }
}

/// Broadcasts "connection problem" changes from a repository's poll loop to any number of listeners.
public final class ConnectionProblemMonitor: @unchecked Sendable {
    private let lock = NSLock()
    private var hasProblem = false
    private var continuations: [UUID: AsyncStream<Bool>.Continuation] = [:]

    public init() {}

    /// Yields the current state first, then every change (`true` = problem, `false` = recovered).
    public func stream() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let id = UUID()
            lock.lock()
            continuations[id] = continuation
            continuation.yield(hasProblem)
            lock.unlock()
            continuation.onTermination = { [weak self] _ in
                self?.lock.lock()
                self?.continuations.removeValue(forKey: id)
                self?.lock.unlock()
            }
        }
    }

    /// Reports the latest poll state; listeners only hear about actual changes.
    public func update(hasProblem newValue: Bool) {
        lock.lock()
        defer { lock.unlock() }
        guard newValue != hasProblem else { return }
        hasProblem = newValue
        for continuation in continuations.values {
            continuation.yield(newValue)
        }
    }
}

/// Mocks never lose their connection, so this stream stays quiet. Real repositories override it.
extension AsyncStream where Element == Bool {
    static var noConnectionProblem: AsyncStream<Bool> {
        AsyncStream { $0.finish() }
    }
}
