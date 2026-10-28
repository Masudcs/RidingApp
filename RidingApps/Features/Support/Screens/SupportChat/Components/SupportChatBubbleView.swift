import SwiftUI

/// One chat bubble; the user's messages are on the right in the brand color.
struct SupportChatBubbleView: View {
    let text: String
    let sentAt: Date
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                Text(text)
                    .font(BrandTypography.body)
                Text(sentAt, style: .time)
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

#Preview("Bubbles") {
    VStack(spacing: 8) {
        SupportChatBubbleView(text: "Hi! How can I help with your ride?", sentAt: Date(), isMine: false)
        SupportChatBubbleView(text: "I left my phone charger in the car.", sentAt: Date(), isMine: true)
    }
    .padding()
}

#Preview("Bubbles - Dark") {
    VStack(spacing: 8) {
        SupportChatBubbleView(text: "Hi! How can I help with your ride?", sentAt: Date(), isMine: false)
        SupportChatBubbleView(text: "I left my phone charger in the car.", sentAt: Date(), isMine: true)
    }
    .padding()
    .background(BrandColor.background)
    .preferredColorScheme(.dark)
}

#endif
