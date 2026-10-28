import Foundation

/// One chat line. `id` must be unique and stable because the chat screen uses it to skip duplicates.
public struct SupportChatMessage: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let isFromSupport: Bool
    public let text: String
    public let sentAt: Date

    public init(id: String = UUID().uuidString, isFromSupport: Bool, text: String, sentAt: Date = Date()) {
        self.id = id
        self.isFromSupport = isFromSupport
        self.text = text
        self.sentAt = sentAt
    }
}

/// Failures from `ISupportChatRepository`.
public enum SupportChatError: Error, Sendable, Equatable {
    case emptyMessage
}

#if DEBUG

// Fixed fake data for SwiftUI previews. Debug builds only, so none of it ships.

public extension SupportChatMessage {
    static func mockList() -> [SupportChatMessage] {
        let now = Date()
        return [
            SupportChatMessage(id: "msg-1", isFromSupport: true, text: "Hi! I'm here to help. What's going on with your ride?", sentAt: now.addingTimeInterval(-300)),
            SupportChatMessage(id: "msg-2", isFromSupport: false, text: "I think I left my phone charger in the car.", sentAt: now.addingTimeInterval(-240)),
            SupportChatMessage(id: "msg-3", isFromSupport: true, text: "Sorry about that! I've reached out to your driver about the lost item.", sentAt: now.addingTimeInterval(-180))
        ]
    }
}

#endif
