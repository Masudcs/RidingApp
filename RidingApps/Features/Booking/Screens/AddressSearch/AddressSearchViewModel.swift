import Combine
import Foundation
import Observation

/// Backs the address search sheet used for pickup, stop, dropoff and saved places. Typing feeds
/// the repository; picking a row resolves it to a real location and reports it via `onSelect`.
@MainActor @Observable
public final class AddressSearchViewModel {
    /// Every change is forwarded to the repository, which ignores blank text.
    public var query = "" {
        didSet { repository.updateQuery(query) }
    }
    public private(set) var suggestions: [AddressSuggestion] = []
    /// True while a tapped suggestion is being looked up; rows are disabled meanwhile.
    public private(set) var isResolving = false
    /// Set when a tapped suggestion could not be turned into a location.
    public private(set) var errorMessage: String?

    @ObservationIgnored private let repository: IAddressSearchRepository
    @ObservationIgnored private let onSelect: (NamedLocation) -> Void
    @ObservationIgnored private let onCancel: () -> Void
    @ObservationIgnored private var resolveTask: Task<Void, Never>?
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    public init(
        repository: IAddressSearchRepository? = nil,
        onSelect: @escaping (NamedLocation) -> Void,
        onCancel: @escaping () -> Void
    ) {
        let repository = repository ?? AddressSearchRepository()
        self.repository = repository
        self.onSelect = onSelect
        self.onCancel = onCancel
        repository.suggestionsPublisher
            .sink { [weak self] suggestions in self?.suggestions = suggestions }
            .store(in: &cancellables)
    }

    public func didSelect(_ suggestion: AddressSuggestion) {
        // A second tap while the first lookup runs would report two locations.
        guard !isResolving else { return }
        isResolving = true
        errorMessage = nil
        resolveTask = Task {
            let location = await repository.resolve(suggestion)
            isResolving = false
            // The sheet may have been cancelled while resolving; don't report a location after that.
            guard !Task.isCancelled else { return }
            if let location {
                onSelect(location)
            } else {
                errorMessage = String(localized: "We couldn't find that address. Please try another one.")
            }
        }
    }

    public func didTapCancel() {
        resolveTask?.cancel()
        resolveTask = nil
        onCancel()
    }
}

#if DEBUG

extension AddressSearchViewModel {
    /// Preview state with a fake repository. An empty `query` is the initial prompt; `isEmptyView`
    /// is "no results"; `isLoading` is a tapped row being resolved; `isError` a failed lookup.
    convenience init(isPreview: Bool = true, query: String = "Gulshan", isLoading: Bool = false, isError: Bool = false, isEmptyView: Bool = false) {
        self.init(repository: PreviewAddressSearchRepository(), onSelect: { _ in }, onCancel: {})
        self.query = query
        suggestions = isEmptyView || query.isEmpty ? [] : AddressSuggestion.mockList()
        isResolving = isLoading
        if isError {
            errorMessage = "We couldn't find that address. Please try another one."
        }
    }
}

#endif
