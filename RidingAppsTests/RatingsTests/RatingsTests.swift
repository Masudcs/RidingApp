import Testing
import Foundation
@testable import RidingApps

@Test func submitRatingIsRecordedAndRetrievable() async throws {
    let service = MockRatingRepository()

    let rating = try await service.submitRating(
        tripId: "trip-1",
        raterId: "rider-1",
        raterRole: .rider,
        ratedUserId: "driver-1",
        ratedUserName: "Karim Rahman",
        stars: 5,
        comment: "  Great ride!  ",
        tags: [.safeDriving, .friendly]
    )

    #expect(rating.stars == 5)
    #expect(rating.comment == "Great ride!")

    let received = try await service.ratingsReceived(byUserId: "driver-1")
    #expect(received.count == 1)
    #expect(received[0].id == rating.id)
}

@Test func hasRatedReflectsSubmittedRatings() async throws {
    let service = MockRatingRepository()
    #expect(try await service.hasRated(tripId: "trip-2", raterId: "rider-2") == false)

    _ = try await service.submitRating(
        tripId: "trip-2",
        raterId: "rider-2",
        raterRole: .rider,
        ratedUserId: "driver-2",
        ratedUserName: "Selim Mia",
        stars: 4,
        comment: nil,
        tags: []
    )

    #expect(try await service.hasRated(tripId: "trip-2", raterId: "rider-2"))
}

@Test func submittingASecondRatingForTheSameTripThrows() async throws {
    let service = MockRatingRepository()
    _ = try await service.submitRating(
        tripId: "trip-3",
        raterId: "rider-3",
        raterRole: .rider,
        ratedUserId: "driver-3",
        ratedUserName: "Rafiq Islam",
        stars: 3,
        comment: nil,
        tags: []
    )

    await #expect(throws: RatingError.alreadyRated) {
        _ = try await service.submitRating(
            tripId: "trip-3",
            raterId: "rider-3",
            raterRole: .rider,
            ratedUserId: "driver-3",
            ratedUserName: "Rafiq Islam",
            stars: 2,
            comment: nil,
            tags: []
        )
    }
}

@Test func outOfRangeStarsThrows() async throws {
    let service = MockRatingRepository()
    await #expect(throws: RatingError.invalidStars) {
        _ = try await service.submitRating(
            tripId: "trip-4",
            raterId: "rider-4",
            raterRole: .rider,
            ratedUserId: "driver-4",
            ratedUserName: "Abul Hossain",
            stars: 6,
            comment: nil,
            tags: []
        )
    }
}

@Test func concurrentDoubleSubmitRecordsOnlyOneRating() async throws {
    let service = MockRatingRepository()

    func submit(stars: Int) async -> Bool {
        do {
            _ = try await service.submitRating(
                tripId: "trip-5",
                raterId: "rider-5",
                raterRole: .rider,
                ratedUserId: "driver-5",
                ratedUserName: "Selim Mia",
                stars: stars,
                comment: nil,
                tags: []
            )
            return true
        } catch {
            return false
        }
    }

    async let first = submit(stars: 5)
    async let second = submit(stars: 4)
    let results = await [first, second]

    #expect(results.filter { $0 }.count == 1)
    let received = try await service.ratingsReceived(byUserId: "driver-5")
    #expect(received.count == 1)
}

@Test func blankCommentIsStoredAsNil() async throws {
    let service = MockRatingRepository()
    let rating = try await service.submitRating(
        tripId: "trip-6",
        raterId: "rider-6",
        raterRole: .rider,
        ratedUserId: "driver-6",
        ratedUserName: "Abul Hossain",
        stars: 3,
        comment: "   \n ",
        tags: []
    )
    #expect(rating.comment == nil)
}
