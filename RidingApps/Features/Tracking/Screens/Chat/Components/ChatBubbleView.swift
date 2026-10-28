import SwiftUI

/// A single message bubble: own messages sit right in the brand color, the other party's left.
struct ChatBubbleView: View {
    let message: ChatMessage
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(BrandTypography.body)
                Text(message.sentAt, style: .time)
                    .font(BrandTypography.caption)
                    .foregroundStyle(isMine ? Color.white.opacity(0.8) : BrandColor.textSecondary)
            }
            .padding(12)
            .foregroundStyle(isMine ? Color.white : BrandColor.textPrimary)
            .background(isMine ? BrandColor.primary : BrandColor.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if !isMine { Spacer(minLength: 40) }
        }
    }
}

#if DEBUG

#Preview("Mine") {
    ChatBubbleView(message: .mock(senderRole: .rider, text: "Coming down now."), isMine: true)
        .padding()
}

#Preview("Theirs") {
    ChatBubbleView(message: .mock(senderRole: .driver), isMine: false)
        .padding()
}

#Preview("Long text") {
    VStack {
        ChatBubbleView(message: .mock(senderRole: .driver, text: ChatMessage.mockLongText), isMine: false)
        ChatBubbleView(message: .mock(senderRole: .rider, text: ChatMessage.mockLongText), isMine: true)
    }
    .padding()
}

#endif
