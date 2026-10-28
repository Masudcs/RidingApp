import Foundation

/// Quick-pick reasons attached to a rating, so most riders/drivers never have to type a comment.
public enum RatingTag: String, Codable, Sendable, CaseIterable, Identifiable {
    case safeDriving
    case cleanVehicle
    case onTime
    case friendly
    case greatConversation
    case politeRider
    case respectful
    case lateArrival
    case unsafeDriving
    case rudeInteraction
    case dirtyVehicle
    case tookLongRoute

    public var id: String { rawValue }

    /// Localized label shown on the tag chip and in the rating history.
    public var displayName: String {
        switch self {
        case .safeDriving: return String(localized: "Safe driving")
        case .cleanVehicle: return String(localized: "Clean vehicle")
        case .onTime: return String(localized: "On time")
        case .friendly: return String(localized: "Friendly")
        case .greatConversation: return String(localized: "Great conversation")
        case .politeRider: return String(localized: "Polite")
        case .respectful: return String(localized: "Respectful")
        case .lateArrival: return String(localized: "Late arrival")
        case .unsafeDriving: return String(localized: "Unsafe driving")
        case .rudeInteraction: return String(localized: "Rude interaction")
        case .dirtyVehicle: return String(localized: "Dirty vehicle")
        case .tookLongRoute: return String(localized: "Took a long route")
        }
    }

    /// Which tags make sense to offer, based on who is being rated and how many stars they got.
    public static func suggestions(forRatedRole ratedRole: UserRole, stars: Int) -> [RatingTag] {
        let positive: [RatingTag]
        let negative: [RatingTag]
        switch ratedRole {
        case .driver:
            positive = [.safeDriving, .cleanVehicle, .onTime, .friendly, .greatConversation]
            negative = [.lateArrival, .unsafeDriving, .rudeInteraction, .dirtyVehicle, .tookLongRoute]
        case .rider:
            positive = [.onTime, .politeRider, .respectful, .friendly]
            negative = [.lateArrival, .rudeInteraction]
        }
        return stars >= 4 ? positive : negative
    }
}

/// One rating a user left for the other party of a trip. A rater can rate a trip once.
public struct Rating: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let tripId: String
    public let raterId: String
    public let raterRole: UserRole
    public let ratedUserId: String
    public let ratedUserName: String
    /// 1...5.
    public let stars: Int
    public let comment: String?
    public let tags: [RatingTag]
    /// When the rating was made; history is sorted by this, newest first.
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        tripId: String,
        raterId: String,
        raterRole: UserRole,
        ratedUserId: String,
        ratedUserName: String,
        stars: Int,
        comment: String?,
        tags: [RatingTag],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.tripId = tripId
        self.raterId = raterId
        self.raterRole = raterRole
        self.ratedUserId = ratedUserId
        self.ratedUserName = ratedUserName
        self.stars = stars
        self.comment = comment
        self.tags = tags
        self.createdAt = createdAt
    }
}

/// Rule violations the UI treats specially (not generic network failures).
public enum RatingError: Error, Sendable, Equatable {
    case invalidStars
    case alreadyRated
}

#if DEBUG

// Fixed fake data for SwiftUI previews. Debug builds only, so none of it ships.
// Defaults let a preview override just the field it is about.

public extension Rating {
    static func mock(
        id: String = "rating-1",
        stars: Int = 5,
        comment: String? = "Smooth ride and a very polite driver.",
        tags: [RatingTag] = [.safeDriving, .onTime],
        daysAgo: Int = 1
    ) -> Rating {
        Rating(
            id: id,
            tripId: "trip-\(id)",
            raterId: "rider-1",
            raterRole: .rider,
            ratedUserId: "driver-1",
            ratedUserName: "Karim Rahman",
            stars: stars,
            comment: comment,
            tags: tags,
            createdAt: Date().addingTimeInterval(-Double(daysAgo) * 86_400)
        )
    }

    /// Ratings in newest-first order, from great to poor, with and without comments and tags.
    static func mockList() -> [Rating] {
        [
            .mock(id: "rating-1", stars: 5, daysAgo: 1),
            .mock(id: "rating-2", stars: 4, comment: nil, tags: [.friendly], daysAgo: 3),
            .mock(id: "rating-3", stars: 2, comment: "Took a longer route than needed.", tags: [.tookLongRoute, .lateArrival], daysAgo: 8),
            .mock(id: "rating-4", stars: 5, comment: nil, tags: [], daysAgo: 20)
        ]
    }
}

#endif
