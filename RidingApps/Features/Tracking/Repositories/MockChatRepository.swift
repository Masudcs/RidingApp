import Foundation

/// Since this is a single-device demo, there's no real counterpart typing back. To make the
/// thread feel alive, a canned reply is synthesized a couple of seconds after each message —
/// mirrors how MockBookingRepository/MockTrackingRepository simulate the other side of a two-party flow.
public actor MockChatRepository: IChatRepository {
    /// Full history per trip, replayed to every new subscriber.
    private var messagesByTrip: [String: [ChatMessage]] = [:]
    /// Live subscribers per trip; removed when their stream terminates.
    private var continuationsByTrip: [String: [UUID: AsyncStream<ChatMessage>.Continuation]] = [:]

    private let cannedReplies = [
        "Sure, on my way!",
        "Okay, thanks for letting me know.",
        "I'll be there in a few minutes.",
        "Got it 👍",
        "No problem, see you soon."
    ]

    public init() {}

    public func messageStream(tripId: String) async -> AsyncStream<ChatMessage> {
        AsyncStream { continuation in
            let subscriberId = UUID()
            for message in messagesByTrip[tripId] ?? [] {
                continuation.yield(message)
            }
            continuationsByTrip[tripId, default: [:]][subscriberId] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeSubscriber(subscriberId, tripId: tripId) }
            }
        }
    }

    public func sendMessage(tripId: String, senderId: String, senderRole: UserRole, text: String) async throws -> ChatMessage {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ChatError.emptyMessage }

        await MockLatency.short()

        let message = ChatMessage(tripId: tripId, senderId: senderId, senderRole: senderRole, text: trimmed)
        record(message, tripId: tripId)

        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Double.random(in: 1.5...3)))
            await self?.sendAutoReply(tripId: tripId, replyingToRole: senderRole)
        }

        return message
    }

    /// Answers as the other party so a single-device demo still has a conversation.
    private func sendAutoReply(tripId: String, replyingToRole: UserRole) {
        let replyRole: UserRole = replyingToRole == .rider ? .driver : .rider
        let reply = ChatMessage(
            tripId: tripId,
            senderId: "auto-\(replyRole.rawValue)",
            senderRole: replyRole,
            text: cannedReplies.randomElement() ?? cannedReplies[0]
        )
        record(reply, tripId: tripId)
    }

    private func record(_ message: ChatMessage, tripId: String) {
        messagesByTrip[tripId, default: []].append(message)
        for continuation in continuationsByTrip[tripId, default: [:]].values {
            continuation.yield(message)
        }
    }

    private func removeSubscriber(_ id: UUID, tripId: String) {
        continuationsByTrip[tripId]?.removeValue(forKey: id)
    }
}
