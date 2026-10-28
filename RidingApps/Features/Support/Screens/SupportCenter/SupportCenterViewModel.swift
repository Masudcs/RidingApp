import Foundation
import Observation
import Combine

/// State for the Help & Support screen: FAQ, the "contact support" form and the history of
/// submitted requests. Requests go to `ISupportRequestRepository`; `SupportRequestStore` only caches
/// the accepted ones for the history list.
@MainActor
@Observable
public final class SupportCenterViewModel {
    public var category: SupportRequestCategory = .tripIssue
    public var selectedTripId: String?
    public var message = ""
    public private(set) var didSubmit = false
    public private(set) var isSubmitting = false
    /// Set when sending fails (the message stays in the form so it can be retried); cleared on the next try.
    public private(set) var errorMessage: String?
    public private(set) var requests: [SupportRequest] = []
    private var history: [RideHistoryEntry] = []

    public let faqItems = FAQItem.all

    @ObservationIgnored private let store: SupportRequestStore
    @ObservationIgnored private let repository: ISupportRequestRepository
    @ObservationIgnored private let logger = AppLogger(category: "SupportCenter")
    @ObservationIgnored private var cancellable: AnyCancellable?
    /// Set only by the debug preview initializer; submitting never reaches a repository or store.
    @ObservationIgnored private var isPreview = false

    public init(
        userId: String,
        store: SupportRequestStore? = nil,
        repository: ISupportRequestRepository = AppEnvironment.current.usesMockServices ? MockSupportRequestRepository() : SupportRequestRepository()
    ) {
        let store = store ?? SupportRequestStore(userId: userId)
        self.store = store
        self.repository = repository
        self.requests = store.requests
        cancellable = store.$requests
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] requests in
                MainActor.assumeIsolated { self?.requests = requests }
            }
    }

    /// Latest 10 rides, offered when reporting a lost item.
    public var recentTrips: [RideHistoryEntry] {
        Array(history.prefix(10))
    }

    public var showsTripPicker: Bool {
        category == .lostItem && !recentTrips.isEmpty
    }

    public var canSubmit: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The text that is saved: the trimmed message, prefixed with the chosen ride for lost items.
    private var composedMessage: String {
        guard category == .lostItem, let selectedTripId, let trip = recentTrips.first(where: { $0.tripId == selectedTripId }) else {
            return trimmedMessage
        }
        let when = trip.completedAt.formatted(date: .abbreviated, time: .shortened)
        return String(localized: "Trip: \(trip.pickupTitle) \u{2192} \(trip.dropoffTitle) on \(when). \(trimmedMessage)")
    }

    /// Ride history comes from the app-wide store, which the screen reads from the environment.
    public func didUpdateHistory(_ entries: [RideHistoryEntry]) {
        history = entries
    }

    public func tripLabel(for trip: RideHistoryEntry) -> String {
        let when = trip.completedAt.formatted(date: .abbreviated, time: .shortened)
        return String(localized: "\(trip.pickupTitle) \u{2192} \(trip.dropoffTitle) \u{00B7} \(when)")
    }

    /// Sends the request. Ignored while one is already in flight. On success the form is cleared and
    /// the request is cached locally; on failure the text stays so the user can tap again.
    public func didTapSubmit() {
        guard !isPreview else { return }
        guard canSubmit else { return }
        isSubmitting = true
        didSubmit = false
        errorMessage = nil
        let selectedCategory = category
        let text = composedMessage
        Task {
            do {
                let request = try await repository.submitSupportRequest(category: selectedCategory, message: text)
                store.record(request)
                message = ""
                selectedTripId = nil
                didSubmit = true
            } catch {
                logger.error("Failed to submit support request: \(error)")
                errorMessage = String(localized: "Couldn't send your request. Please try again.")
            }
            isSubmitting = false
        }
    }
}

#if DEBUG

extension SupportCenterViewModel {
    /// Fixed fake state. Loading is a request being sent, empty has no past requests, error shows
    /// the send failure, and `isSubmitted` shows the thank-you note.
    convenience init(
        isPreview: Bool = true,
        isLoading: Bool = false,
        isError: Bool = false,
        isEmptyView: Bool = false,
        isSubmitted: Bool = false
    ) {
        let defaults = UserDefaults(suiteName: "preview.supportRequests")!
        self.init(
            userId: "preview-user",
            store: SupportRequestStore(userId: "preview-user", defaults: defaults),
            repository: MockSupportRequestRepository()
        )
        self.isPreview = isPreview
        self.requests = isEmptyView ? [] : SupportRequest.mockList()
        self.message = isLoading || isError ? "The driver took a longer route than expected." : ""
        self.isSubmitting = isLoading
        self.didSubmit = isSubmitted
        self.errorMessage = isError ? String(localized: "Couldn't send your request. Please try again.") : nil
    }
}

#endif
