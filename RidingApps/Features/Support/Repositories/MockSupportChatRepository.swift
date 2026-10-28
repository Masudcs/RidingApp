import Foundation

/// Simulates a live support agent with canned, contextual replies — there's no real support
/// backend, but a scripted back-and-forth is more honest than a chat box that never responds.
public actor MockSupportChatRepository: ISupportChatRepository {
    private var messages: [SupportChatMessage] = [
        SupportChatMessage(isFromSupport: true, text: String(localized: "Hi! I'm here to help. What's going on with your ride?"))
    ]
    private var continuations: [UUID: AsyncStream<SupportChatMessage>.Continuation] = [:]

    public init() {}

    /// Replays the conversation so far, then yields new messages to every subscriber.
    public func messageStream() -> AsyncStream<SupportChatMessage> {
        AsyncStream { continuation in
            let subscriberId = UUID()
            for message in messages {
                continuation.yield(message)
            }
            continuations[subscriberId] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeSubscriber(subscriberId) }
            }
        }
    }

    public func sendMessage(text: String) async throws -> SupportChatMessage {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SupportChatError.emptyMessage }

        await MockLatency.short()

        let message = SupportChatMessage(isFromSupport: false, text: trimmed)
        record(message)

        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Double.random(in: 1.5...3)))
            await self?.sendReply(to: trimmed)
        }

        return message
    }

    private func sendReply(to text: String) {
        record(SupportChatMessage(isFromSupport: true, text: Self.reply(for: text)))
    }

    private func record(_ message: SupportChatMessage) {
        messages.append(message)
        for continuation in continuations.values {
            continuation.yield(message)
        }
    }

    private func removeSubscriber(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }

    private static func reply(for text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("refund") || lowercased.contains("charge") || lowercased.contains("payment") {
            return String(localized: "I've flagged this for our payments team \u{2014} you should see a resolution within 24 hours.")
        } else if lowercased.contains("lost") || lowercased.contains("item") || lowercased.contains("left") {
            return String(localized: "Sorry about that! I've reached out to your driver about the lost item \u{2014} I'll update you here.")
        } else if lowercased.contains("driver") || lowercased.contains("rider") {
            return String(localized: "Thanks for the detail \u{2014} I've noted this on the account and I'm looking into it now.")
        } else {
            return String(localized: "Got it, thanks for explaining. Give me a moment to look into this for you.")
        }
    }
}
