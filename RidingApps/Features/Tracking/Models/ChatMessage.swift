import Foundation

/// One chat message in a trip thread. `id` is what the UI uses to avoid showing a message twice.
public struct ChatMessage: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let tripId: String
    public let senderId: String
    public let senderRole: UserRole
    public let text: String
    public let sentAt: Date

    public init(
        id: String = UUID().uuidString,
        tripId: String,
        senderId: String,
        senderRole: UserRole,
        text: String,
        sentAt: Date = Date()
    ) {
        self.id = id
        self.tripId = tripId
        self.senderId = senderId
        self.senderRole = senderRole
        self.text = text
        self.sentAt = sentAt
    }
}

/// Errors raised by chat before or instead of a network call.
public enum ChatError: Error, Sendable, Equatable {
    case emptyMessage
}

#if DEBUG

// Fixed fake data for SwiftUI previews. Debug builds only, so none of it ships.
// Defaults let a preview override just the field it is about.

public extension ChatMessage {
    static func mock(
        id: String = "message-1",
        senderRole: UserRole = .driver,
        text: String = "I'm at the main gate, in a white Toyota."
    ) -> ChatMessage {
        ChatMessage(
            id: id,
            tripId: "trip-1",
            senderId: senderRole == .rider ? "rider-1" : "driver-1",
            senderRole: senderRole,
            text: text,
            sentAt: Date()
        )
    }

    /// A short back-and-forth between rider and driver, oldest first.
    static func mockThread() -> [ChatMessage] {
        [
            .mock(id: "message-1", senderRole: .driver, text: "I'm at the main gate, in a white Toyota."),
            .mock(id: "message-2", senderRole: .rider, text: "Great, coming down now."),
            .mock(id: "message-3", senderRole: .driver, text: "No hurry, I'll wait."),
            .mock(id: "message-4", senderRole: .rider, text: "Thanks!")
        ]
    }

    static let mockLongText = "I'm standing next to the blue gate beside the pharmacy, about fifty meters past the traffic signal on Gulshan Avenue, wearing a green jacket and holding a red umbrella, so please call me if you cannot find me."
}

#endif
