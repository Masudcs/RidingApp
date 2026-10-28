import Foundation

/// Real chat backend. There is no push channel yet, so incoming messages are polled.
/// TODO(real API): replace polling with a websocket/SSE feed when the server offers one.
public final class ChatRepository: IChatRepository {
    /// Endpoint paths, relative to the API base URL.
    private enum Paths {
        static func messages(tripId: String) -> String { "trips/\(tripId.pathEscaped)/chat/messages" }
    }

    /// Body for `POST trips/{id}/chat/messages`.
    private struct SendMessageBody: Encodable {
        let senderId: String
        let senderRole: UserRole
        let text: String
    }

    private let apiClient: APIClient
    private let backoff: PollBackoff
    private let monitor = ConnectionProblemMonitor()

    /// `backoff` sets the poll interval (its base delay) and the retry delays after failures.
    public init(
        apiClient: APIClient = APIClientFactory.make(),
        backoff: PollBackoff = PollBackoff(baseDelay: .seconds(2))
    ) {
        self.apiClient = apiClient
        self.backoff = backoff
    }

    public func connectionProblemStream() -> AsyncStream<Bool> {
        monitor.stream()
    }

    /// Trims the text and rejects empty input before hitting the network (`ChatError.emptyMessage`).
    public func sendMessage(tripId: String, senderId: String, senderRole: UserRole, text: String) async throws -> ChatMessage {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ChatError.emptyMessage }

        let body = try JSONEncoder().encode(SendMessageBody(senderId: senderId, senderRole: senderRole, text: trimmed))
        return try await apiClient.send(Endpoint(path: Paths.messages(tripId: tripId), method: .post, body: body))
    }

    /// Polls the thread and yields each message once, oldest first. A failed poll is retried with
    /// exponential backoff (a flaky connection must not end the stream) and, after repeated
    /// failures, reported through `connectionProblemStream`. Stops when the consumer cancels.
    public func messageStream(tripId: String) async -> AsyncStream<ChatMessage> {
        let apiClient = apiClient
        let monitor = monitor
        let initialBackoff = backoff
        return AsyncStream { continuation in
            let task = Task {
                var backoff = initialBackoff
                var seenIds = Set<String>()
                while !Task.isCancelled {
                    do {
                        let messages: [ChatMessage] = try await apiClient.send(Endpoint(path: Paths.messages(tripId: tripId)))
                        backoff.recordSuccess()
                        for message in messages.sorted(by: { $0.sentAt < $1.sentAt }) where seenIds.insert(message.id).inserted {
                            continuation.yield(message)
                        }
                    } catch is CancellationError {
                        break
                    } catch {
                        backoff.recordFailure()
                    }
                    monitor.update(hasProblem: backoff.hasConnectionProblem)
                    try? await Task.sleep(for: backoff.currentDelay)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
