import Foundation
import Observation

/// Loads the ratings received by one user for `RatingHistoryScreen`.
@MainActor
@Observable
public final class RatingHistoryViewModel {
    public private(set) var state: UIState<[Rating]> = .loading

    @ObservationIgnored private let userId: String
    @ObservationIgnored private let repository: IRatingRepository
    @ObservationIgnored private let logger = AppLogger(category: "Ratings")
    #if DEBUG
    /// Set by the preview initializer so the screen's `.task` cannot overwrite the fake state.
    @ObservationIgnored private var isPreview = false
    #endif

    public init(userId: String, repository: IRatingRepository = RatingRepository.makeDefault()) {
        self.userId = userId
        self.repository = repository
    }

    /// Called from the screen's `.task`. A failure shows the error state, so a later reload
    /// replaces it.
    public func load() async {
        #if DEBUG
        guard !isPreview else { return }
        #endif
        do {
            state = .data(data: try await repository.ratingsReceived(byUserId: userId))
        } catch {
            logger.error("Failed to load ratings: \(error)")
            state = .error(message: String(localized: "Couldn't load your ratings. Please try again."))
        }
    }
}

#if DEBUG

extension RatingHistoryViewModel {
    /// Fixed fake state for previews; `load()` is disabled.
    convenience init(
        isPreview: Bool = true,
        isLoading: Bool = false,
        isError: Bool = false,
        isEmptyView: Bool = false
    ) {
        self.init(userId: "preview-user", repository: MockRatingRepository())
        self.isPreview = isPreview
        if isLoading {
            state = .loading
        } else if isError {
            state = .error(message: String(localized: "Couldn't load your ratings. Please try again."))
        } else if isEmptyView {
            state = .data(data: [])
        } else {
            state = .data(data: Rating.mockList())
        }
    }
}

#endif
