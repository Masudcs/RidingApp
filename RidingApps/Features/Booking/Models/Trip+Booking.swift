import Foundation

public extension Trip {
    /// The fare a driver sees on an incoming request: the rider's latest offer.
    var latestRiderOfferAmount: Money {
        offers.last { $0.author == .rider }?.amount ?? suggestedFare
    }
}

public extension Money {
    /// Parses free-form BDT text typed into an offer field. Returns nil for blank, non-numeric,
    /// zero/negative or absurdly large input (`Money.bdt` would trap on NaN/infinity).
    static func bdt(parsing text: String) -> Money? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value.isFinite, value > 0, value <= 1_000_000 else { return nil }
        return .bdt(value)
    }
}

#if DEBUG

// Fixed fake data for SwiftUI previews. Debug builds only, so none of it ships.
// Builds on `Trip.mock` from Core.

public extension Trip {
    /// A negotiation in progress. The rider can only accept when the driver made the last offer.
    static func mockNegotiating(lastOfferBy: FareOffer.Author = .driver, womenSafeModeRequested: Bool = false) -> Trip {
        var trip = Trip.mock(status: .negotiating, womenSafeModeRequested: womenSafeModeRequested)
        trip.offers = [.mock(author: .rider, taka: 180), .mock(author: .driver, taka: 210)]
        if lastOfferBy == .rider {
            trip.offers.append(.mock(author: .rider, taka: 200))
        }
        return trip
    }

    /// A matched driver whose free-cancellation window has already run out.
    static func mockPastFreeCancellationWindow() -> Trip {
        var trip = Trip.mock(status: .driverAssigned)
        trip.driverAssignedAt = Date().addingTimeInterval(-(CancellationPolicy.freeWindow + 60))
        return trip
    }

    /// Overlong place names, to check truncation on request cards.
    static func mockLongText() -> Trip {
        Trip(
            id: "trip-long",
            status: .negotiating,
            vehicleType: .premium,
            pickup: NamedLocation(
                id: "long-pickup",
                title: "Bangabandhu International Conference Center, Agargaon Administrative Area",
                subtitle: "Sher-e-Bangla Nagar, Dhaka",
                point: .mockPickup
            ),
            dropoff: NamedLocation(
                id: "long-dropoff",
                title: "Hazrat Shahjalal International Airport, Terminal 3 Departure Level",
                subtitle: "Airport Road, Dhaka",
                point: .mockDropoff
            ),
            suggestedFare: .bdt(1450),
            offers: [.mock(author: .rider, taka: 1450)],
            riderId: "rider-1",
            riderName: "Tania Ahmed"
        )
    }
}

#endif
