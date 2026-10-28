import SwiftUI

/// Driver-side card for one incoming ride request: accept, decline, or send a counter-offer.
/// It only reports the choice through its closures; the parent talks to the repository.
public struct DriverIncomingRequestCard: View {
    private let trip: Trip
    private let onAccept: () -> Void
    private let onCounter: (Money) -> Void
    private let onDecline: () -> Void

    @State private var counterAmountText: String = ""

    public init(
        trip: Trip,
        onAccept: @escaping () -> Void,
        onCounter: @escaping (Money) -> Void,
        onDecline: @escaping () -> Void
    ) {
        self.trip = trip
        self.onAccept = onAccept
        self.onCounter = onCounter
        self.onDecline = onDecline
    }


    public var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: trip.vehicleType.systemImageName)
                        .foregroundStyle(BrandColor.primary)
                    Text(trip.vehicleType.displayName)
                        .font(BrandTypography.headline)
                    Spacer()
                    Text(trip.latestRiderOfferAmount.formatted)
                        .font(BrandTypography.title)
                        .foregroundStyle(BrandColor.primary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label(trip.pickup.title, systemImage: "circle.fill")
                        .font(BrandTypography.body)
                    Label(trip.dropoff.title, systemImage: "mappin.circle.fill")
                        .font(BrandTypography.body)
                }
                .foregroundStyle(BrandColor.textSecondary)

                HStack(spacing: 8) {
                    SecondaryButton("Decline", systemImage: "xmark") {
                        onDecline()
                    }
                    PrimaryButton("Accept", systemImage: "checkmark") {
                        onAccept()
                    }
                }

                HStack(spacing: 8) {
                    TextField("Counter offer (BDT)", text: $counterAmountText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)

                    Button("Send") {
                        guard let amount = Money.bdt(parsing: counterAmountText) else { return }
                        onCounter(amount)
                        counterAmountText = ""
                    }
                    .disabled(Money.bdt(parsing: counterAmountText) == nil)
                }
            }
        }
    }
}

#if DEBUG

#Preview("Car request") {
    DriverIncomingRequestCard(trip: .mockNegotiating(), onAccept: {}, onCounter: { _ in }, onDecline: {})
        .padding()
        .background(BrandColor.background)
}

#Preview("Bike request") {
    DriverIncomingRequestCard(
        trip: .mock(status: .negotiating, vehicleType: .bike),
        onAccept: {},
        onCounter: { _ in },
        onDecline: {}
    )
    .padding()
    .background(BrandColor.background)
}

#Preview("Long text") {
    DriverIncomingRequestCard(trip: .mockLongText(), onAccept: {}, onCounter: { _ in }, onDecline: {})
        .padding()
        .background(BrandColor.background)
}

#endif
