import Foundation

/// Reads and writes ratings. Implemented by `RatingRepository` (real API) and
/// `MockRatingRepository`; get one with `RatingRepository.makeDefault()`.
public protocol IRatingRepository: Sendable {
    /// Throws `RatingError.invalidStars` outside 1...5 and `.alreadyRated` if this rater already
    /// rated the trip. Blank comments are sent as nil.
    func submitRating(
        tripId: String,
        raterId: String,
        raterRole: UserRole,
        ratedUserId: String,
        ratedUserName: String,
        stars: Int,
        comment: String?,
        tags: [RatingTag]
    ) async throws -> Rating

    /// Whether `raterId` has already rated `tripId`.
    func hasRated(tripId: String, raterId: String) async throws -> Bool

    /// Ratings someone else has left about `userId`, most recent first.
    func ratingsReceived(byUserId userId: String) async throws -> [Rating]
}

/// Real ratings API client. A 409 from the server is mapped to `RatingError.alreadyRated`.
public final class RatingRepository: IRatingRepository {
    /// Body for `POST /ratings`.
    private struct SubmitBody: Codable, Sendable {
        let tripId: String
        let raterId: String
        let raterRole: UserRole
        let ratedUserId: String
        let ratedUserName: String
        let stars: Int
        let comment: String?
        let tags: [RatingTag]
    }

    /// Response from `GET /ratings/exists`.
    private struct HasRatedResponse: Codable, Sendable {
        let hasRated: Bool
    }

    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    /// Picks the mock or the real repository the same way for every screen that needs one.
    public static func makeDefault() -> IRatingRepository {
        if AppEnvironment.current.usesMockServices {
            return MockRatingRepository.shared
        }
        return RatingRepository(apiClient: APIClientFactory.make())
    }

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

        let trimmedComment = comment?.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = SubmitBody(
            tripId: tripId,
            raterId: raterId,
            raterRole: raterRole,
            ratedUserId: ratedUserId,
            ratedUserName: ratedUserName,
            stars: stars,
            comment: (trimmedComment?.isEmpty ?? true) ? nil : trimmedComment,
            tags: tags
        )
        do {
            return try await apiClient.send(Endpoint(path: "/ratings", method: .post, body: try JSONEncoder().encode(body)))
        } catch NetworkError.server(statusCode: 409) {
            throw RatingError.alreadyRated
        }
    }

    public func hasRated(tripId: String, raterId: String) async throws -> Bool {
        let response: HasRatedResponse = try await apiClient.send(Endpoint(
            path: "/ratings/exists",
            queryItems: [URLQueryItem(name: "tripId", value: tripId), URLQueryItem(name: "raterId", value: raterId)]
        ))
        return response.hasRated
    }

    /// Sorting is done here, not by the server.
    public func ratingsReceived(byUserId userId: String) async throws -> [Rating] {
        let ratings: [Rating] = try await apiClient.send(Endpoint(
            path: "/ratings/received",
            queryItems: [URLQueryItem(name: "userId", value: userId)]
        ))
        return ratings.sorted { $0.createdAt > $1.createdAt }
    }
}
