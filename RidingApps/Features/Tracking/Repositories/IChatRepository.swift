import Foundation

/// Sends and receives the in-trip chat between rider and driver.
public protocol IChatRepository: Sendable {
    /// Throws `ChatError.emptyMessage` for blank text; other errors come from the backend.
    func sendMessage(tripId: String, senderId: String, senderRole: UserRole, text: String) async throws -> ChatMessage
    /// Replays every message already sent for the trip, then yields new ones as they arrive.
    func messageStream(tripId: String) async -> AsyncStream<ChatMessage>
    /// Yields `true` after repeated poll failures and `false` once polling recovers. Starts with the current state.
    func connectionProblemStream() -> AsyncStream<Bool>
}

extension IChatRepository {
    /// Default for repositories that cannot lose a connection (mocks): never reports a problem.
    public func connectionProblemStream() -> AsyncStream<Bool> { .noConnectionProblem }
}
