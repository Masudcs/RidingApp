import SwiftUI

/// The offer chat: bubbles, optional accept button, and a field to propose a different fare.
public struct FareNegotiationView: View {
    private let offers: [FareOffer]
    private let notice: WomenSafeNotice?
    private let errorMessage: String?
    private let acceptTitle: String?
    private let isLoading: Bool
    private let offerText: Binding<String>
    private let canPropose: Bool
    private let onAccept: () -> Void
    private let onPropose: () -> Void

    public init(
        offers: [FareOffer],
        notice: WomenSafeNotice?,
        errorMessage: String?,
        acceptTitle: String?,
        isLoading: Bool,
        offerText: Binding<String>,
        canPropose: Bool,
        onAccept: @escaping () -> Void,
        onPropose: @escaping () -> Void
    ) {
        self.offers = offers
        self.notice = notice
        self.errorMessage = errorMessage
        self.acceptTitle = acceptTitle
        self.isLoading = isLoading
        self.offerText = offerText
        self.canPropose = canPropose
        self.onAccept = onAccept
        self.onPropose = onPropose
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let notice {
                noticeLabel(for: notice)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(offers) { offer in
                        OfferBubbleView(offer: offer)
                    }
                }
                .padding(16)
            }

            if let errorMessage {
                ErrorBanner(errorMessage)
                    .padding(.horizontal, 16)
            }

            if let acceptTitle {
                PrimaryButton(acceptTitle, isLoading: isLoading, action: onAccept)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            HStack(spacing: 8) {
                TextField("Your offer (BDT)", text: offerText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)

                Button("Propose", action: onPropose)
                    .disabled(!canPropose)
            }
            .padding(16)
        }
        .background(BrandColor.background)
    }

    @ViewBuilder
    private func noticeLabel(for notice: WomenSafeNotice) -> some View {
        switch notice {
        case .fallbackDriver:
            Label("No female driver was available nearby — matched with the next available driver", systemImage: "info.circle")
                .font(BrandTypography.caption)
                .foregroundStyle(BrandColor.textSecondary)
        case .matching:
            Label("Matching with a female driver — Women Safe Mode", systemImage: "shield.fill")
                .font(BrandTypography.caption)
                .foregroundStyle(BrandColor.primary)
        }
    }
}

#if DEBUG

private let previewOffers: [FareOffer] = [.mock(author: .rider, taka: 180), .mock(author: .driver, taka: 210)]

#Preview("Driver countered") {
    FareNegotiationView(
        offers: previewOffers,
        notice: nil,
        errorMessage: nil,
        acceptTitle: "Accept \(Money.bdt(210).formatted)",
        isLoading: false,
        offerText: .constant(""),
        canPropose: false,
        onAccept: {},
        onPropose: {}
    )
}

#Preview("Waiting for driver") {
    FareNegotiationView(
        offers: Array(previewOffers.prefix(1)),
        notice: nil,
        errorMessage: nil,
        acceptTitle: nil,
        isLoading: false,
        offerText: .constant("200"),
        canPropose: true,
        onAccept: {},
        onPropose: {}
    )
}

#Preview("No offers") {
    FareNegotiationView(
        offers: [],
        notice: nil,
        errorMessage: nil,
        acceptTitle: nil,
        isLoading: false,
        offerText: .constant(""),
        canPropose: false,
        onAccept: {},
        onPropose: {}
    )
}

#Preview("Loading") {
    FareNegotiationView(
        offers: previewOffers,
        notice: nil,
        errorMessage: nil,
        acceptTitle: "Accept \(Money.bdt(210).formatted)",
        isLoading: true,
        offerText: .constant("200"),
        canPropose: false,
        onAccept: {},
        onPropose: {}
    )
}

#Preview("Error") {
    FareNegotiationView(
        offers: previewOffers,
        notice: nil,
        errorMessage: "Enter a valid fare amount",
        acceptTitle: nil,
        isLoading: false,
        offerText: .constant("abc"),
        canPropose: true,
        onAccept: {},
        onPropose: {}
    )
}

#Preview("Women Safe matching") {
    FareNegotiationView(
        offers: previewOffers,
        notice: .matching,
        errorMessage: nil,
        acceptTitle: nil,
        isLoading: false,
        offerText: .constant(""),
        canPropose: false,
        onAccept: {},
        onPropose: {}
    )
}

#Preview("Women Safe fallback") {
    FareNegotiationView(
        offers: previewOffers,
        notice: .fallbackDriver,
        errorMessage: nil,
        acceptTitle: nil,
        isLoading: false,
        offerText: .constant(""),
        canPropose: false,
        onAccept: {},
        onPropose: {}
    )
}

#endif
