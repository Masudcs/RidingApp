import Foundation

/// In-memory stand-in for the ratings backend (Dev/Staging). Mirrors the real API's rules:
/// stars must be 1...5 and one rater can rate a trip only once.
public actor MockRatingRepository: IRatingRepository {
    private var ratings: [Rating] = []

    /// One in-memory "backend" shared by every screen so ratings submitted in a trip flow show up
    /// in the rating history.
    public static let shared = MockRatingRepository()

    public init() {}

    /// Checks for a duplicate again after the simulated delay, because the actor can run another
    /// submit while this one is suspended.
    public func submitRating(
        tripId: String,
        raterId: String,
        raterRole: UserRole,
        ratedUserId: String,
        ratedUserName: String,
        stars: Int,
        comment: String?,
        tags: [RatingTag]
    ) async throws -> Rating {
        guard (1...5).contains(stars) else { throw RatingError.invalidStars }
        guard !ratings.contains(where: { $0.tripId == tripId && $0.raterId == raterId }) else {
            throw RatingError.alreadyRated
        }

        await MockLatency.short()
        guard !ratings.contains(where: { $0.tripId == tripId && $0.raterId == raterId }) else {
            throw RatingError.alreadyRated
        }

        let trimmedComment = comment?.trimmingCharacters(in: .whitespacesAndNewlines)
        let rating = Rating(
            tripId: tripId,
            raterId: raterId,
            raterRole: raterRole,
            ratedUserId: ratedUserId,
            ratedUserName: ratedUserName,
            stars: stars,
            comment: (trimmedComment?.isEmpty ?? true) ? nil : trimmedComment,
            tags: tags
        )
        ratings.append(rating)
        return rating
    }

    public func hasRated(tripId: String, raterId: String) async throws -> Bool {
        ratings.contains { $0.tripId == tripId && $0.raterId == raterId }
    }

    public func ratingsReceived(byUserId userId: String) async throws -> [Rating] {
        await MockLatency.short()
        return ratings
            .filter { $0.ratedUserId == userId }
            .sorted { $0.createdAt > $1.createdAt }
    }
}
