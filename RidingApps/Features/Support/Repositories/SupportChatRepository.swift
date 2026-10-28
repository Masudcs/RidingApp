import Foundation

/// API-backed support chat. Sending is a POST; receiving is polling (see `messageStream`).
public final class SupportChatRepository: ISupportChatRepository {
    /// Endpoint paths, relative to the API base URL.
    private enum Paths {
        static let messages = "support/chat/messages"
    }

    /// Body for `POST support/chat/messages`.
    private struct SendMessageBody: Encodable {
        let text: String
    }

    private let apiClient: APIClient
    private let backoff: PollBackoff
    private let monitor = ConnectionProblemMonitor()
    private let logger = AppLogger(category: "SupportChat")

    /// `backoff` sets the poll interval (its base delay) and the retry delays after failures.
    public init(
        apiClient: APIClient = APIClientFactory.make(),
        backoff: PollBackoff = PollBackoff(baseDelay: .seconds(3))
    ) {
        self.apiClient = apiClient
        self.backoff = backoff
    }

    public func connectionProblemStream() -> AsyncStream<Bool> {
        monitor.stream()
    }

    /// Trims the text and rejects empty messages before any request is made.
    public func sendMessage(text: String) async throws -> SupportChatMessage {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SupportChatError.emptyMessage }
        let body = try JSONEncoder().encode(SendMessageBody(text: trimmed))
        return try await apiClient.send(Endpoint(path: Paths.messages, method: .post, body: body))
    }

    /// The backend has no push channel yet, so the stream polls the message list and yields unseen messages.
    public func messageStream() async -> AsyncStream<SupportChatMessage> {
        let apiClient = apiClient
        let logger = logger
        let monitor = monitor
        let initialBackoff = backoff
        return AsyncStream { continuation in
            let task = Task {
                var backoff = initialBackoff
                var seenIds = Set<String>()
                while !Task.isCancelled {
                    do {
                        let messages: [SupportChatMessage] = try await apiClient.send(Endpoint(path: Paths.messages))
                        backoff.recordSuccess()
                        for message in messages where seenIds.insert(message.id).inserted {
                            continuation.yield(message)
                        }
                    } catch is CancellationError {
                        break
                    } catch {
                        // Keep polling: one failed poll (e.g. brief loss of signal) shouldn't end the chat.
                        backoff.recordFailure()
                        logger.error("Support chat poll failed: \(error)")
                    }
                    monitor.update(hasProblem: backoff.hasConnectionProblem)
                    try? await Task.sleep(for: backoff.currentDelay)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
