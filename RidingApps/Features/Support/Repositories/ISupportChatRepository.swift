import Foundation

/// Send and receive support chat messages. Real backend: `SupportChatRepository`; mock mode: `MockSupportChatRepository`.
public protocol ISupportChatRepository: Sendable {
    /// Throws `SupportChatError.emptyMessage` for blank text.
    func sendMessage(text: String) async throws -> SupportChatMessage
    /// Replays every message already sent this session, then yields new ones as they arrive.
    func messageStream() async -> AsyncStream<SupportChatMessage>
    /// Yields `true` after repeated poll failures and `false` once polling recovers. Starts with the current state.
    func connectionProblemStream() -> AsyncStream<Bool>
}

extension ISupportChatRepository {
    /// Default for repositories that cannot lose a connection (mocks): never reports a problem.
    public func connectionProblemStream() -> AsyncStream<Bool> { .noConnectionProblem }
}
