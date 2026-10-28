import SwiftUI

/// One offer in the chat: rider offers right-aligned in brand color, driver offers left-aligned.
public struct OfferBubbleView: View {
    private let offer: FareOffer

    public init(offer: FareOffer) {
        self.offer = offer
    }

    public var body: some View {
        HStack {
            if offer.author == .rider { Spacer(minLength: 40) }

            VStack(alignment: offer.author == .rider ? .trailing : .leading, spacing: 4) {
                Text(offer.amount.formatted)
                    .font(BrandTypography.headline)
                Text(offer.createdAt, style: .relative)
                    .font(BrandTypography.caption)
                    .foregroundStyle(offer.author == .rider ? Color.white.opacity(0.8) : BrandColor.textSecondary)
            }
            .padding(12)
            .foregroundStyle(offer.author == .rider ? Color.white : BrandColor.textPrimary)
            .background(offer.author == .rider ? BrandColor.primary : BrandColor.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if offer.author == .driver { Spacer(minLength: 40) }
        }
    }
}

#if DEBUG

#Preview("Rider offer") {
    OfferBubbleView(offer: .mock(author: .rider, taka: 180))
        .padding()
}

#Preview("Driver offer") {
    OfferBubbleView(offer: .mock(author: .driver, taka: 210))
        .padding()
}

#Preview("Large amount") {
    VStack {
        OfferBubbleView(offer: .mock(author: .rider, taka: 123456.5))
        OfferBubbleView(offer: .mock(author: .driver, taka: 123456.5))
    }
    .padding()
}

#endif
