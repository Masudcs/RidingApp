import Foundation
import Observation

/// Drives the post-trip rating screen shown to the rider (or driver) once a trip has ended and,
/// for riders, been paid. Either path out (submit or skip) calls `onDone`, which lets the parent
/// flow move on, so the screen never traps the user.
@MainActor
@Observable
public final class RateTripViewModel {
    /// Defaults to 5 so a one-tap "Submit" works for the common good-trip case.
    public var stars: Int = 5
    public var selectedTags: Set<RatingTag> = []
    /// Optional free text; trimmed (and dropped if empty) before it is sent.
    public var comment: String = ""
    /// True while a submit is in flight; the button shows a spinner and further taps are ignored.
    public private(set) var isSubmitting = false
    public var errorMessage: String?

    public let tripId: String
    public let raterId: String
    public let raterRole: UserRole
    public let ratedUserId: String
    public let ratedUserName: String

    @ObservationIgnored private let onDone: () -> Void
    @ObservationIgnored private let repository: IRatingRepository
    @ObservationIgnored private let logger = AppLogger(category: "Ratings")
    #if DEBUG
    /// Set by the preview initializer so a preview never submits a rating.
    @ObservationIgnored private var isPreview = false
    #endif

    public init(
        tripId: String,
        raterId: String,
        raterRole: UserRole,
        ratedUserId: String,
        ratedUserName: String,
        onDone: @escaping () -> Void,
        repository: IRatingRepository = RatingRepository.makeDefault()
    ) {
        self.tripId = tripId
        self.raterId = raterId
        self.raterRole = raterRole
        self.ratedUserId = ratedUserId
        self.ratedUserName = ratedUserName
        self.onDone = onDone
        self.repository = repository
    }

    /// Who is being rated is the other party in the trip.
    /// The role of the person being rated is the opposite of the person doing the rating.
    private var ratedRole: UserRole { raterRole == .rider ? .driver : .rider }

    /// Tag choices depend on the star count, so they change when the stars change.
    public var suggestedTags: [RatingTag] {
        RatingTag.suggestions(forRatedRole: ratedRole, stars: stars)
    }

    public var promptText: String {
        raterRole == .rider ? String(localized: "How was your driver?") : String(localized: "How was your rider?")
    }

    /// Changing the stars clears the selected tags, because positive and negative tags don't mix.
    public func didSelectStars(_ value: Int) {
        guard (1...5).contains(value) else { return }
        stars = value
        selectedTags = []
    }

    public func didToggleTag(_ tag: RatingTag) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }

    /// Leaves without rating. Ignored while a submit is in flight so we don't finish twice.
    public func didTapSkip() {
        guard !isSubmitting else { return }
        onDone()
    }

    /// Sends the rating. Does nothing if a submit is already running (double tap). With no
    /// `ratedUserId` there is nobody to rate, so it just finishes. On failure the screen stays
    /// open with an error so the user can retry or skip.
    public func didTapSubmit() {
        #if DEBUG
        guard !isPreview else { return }
        #endif
        guard !isSubmitting else { return }
        guard ratedUserId.isEmpty == false else {
            onDone()
            return
        }
        // Set before the Task starts: the Task body runs later, so a second tap could slip in.
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                _ = try await repository.submitRating(
                    tripId: tripId,
                    raterId: raterId,
                    raterRole: raterRole,
                    ratedUserId: ratedUserId,
                    ratedUserName: ratedUserName,
                    stars: stars,
                    comment: comment,
                    tags: Array(selectedTags)
                )
                Analytics.track("rating_submitted", ["stars": String(stars), "role": raterRole.rawValue])
                isSubmitting = false
                onDone()
                return
            } catch RatingError.alreadyRated {
                // The backend already has a rating for this trip (e.g. an earlier attempt whose
                // response was lost). Nothing left to do, so don't keep the user stuck here.
                isSubmitting = false
                onDone()
                return
            } catch {
                logger.error("Failed to submit rating: \(error)")
                errorMessage = String(localized: "Couldn't submit your rating. Please try again.")
            }
            isSubmitting = false
        }
    }
}

#if DEBUG

extension RateTripViewModel {
    /// Fixed fake state for previews; submitting is disabled. `isLoading` is the submitting state.
    convenience init(
        isPreview: Bool = true,
        isLoading: Bool = false,
        isError: Bool = false,
        stars: Int = 5,
        raterRole: UserRole = .rider,
        hasSelectedTags: Bool = false,
        hasLongText: Bool = false
    ) {
        self.init(
            tripId: "trip-1",
            raterId: raterRole == .rider ? "rider-1" : "driver-1",
            raterRole: raterRole,
            ratedUserId: raterRole == .rider ? "driver-1" : "rider-1",
            ratedUserName: raterRole == .rider ? "Karim Rahman" : "Tania Ahmed",
            onDone: {},
            repository: MockRatingRepository()
        )
        self.isPreview = isPreview
        self.stars = stars
        if hasSelectedTags {
            selectedTags = Set(suggestedTags.prefix(2))
        }
        if hasLongText {
            comment = "The driver was on time, kept the car spotless and took a sensible route through heavy traffic. He also helped carry my bags up to the third floor without being asked, which I really appreciated."
        }
        isSubmitting = isLoading
        if isError {
            errorMessage = String(localized: "Couldn't submit your rating. Please try again.")
        }
    }
}

#endif
