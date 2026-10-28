import Foundation
import Observation

/// Second step: choose pickup, optional stops and dropoff. Choosing a dropoff (with a pickup set)
/// immediately continues to the fare step with a `RideRequestDraft`. Pickup and dropoff come from
/// quick-pick suggestions, saved places or the address search sheet.
@MainActor @Observable
public final class LocationPickerViewModel {
    /// Loaded once from the backend when the screen first appears.
    public private(set) var pickupSuggestions: [NamedLocation] = []
    /// Reloaded each time the pickup changes (nearest to pickup first). Also the stop candidates.
    public private(set) var dropoffSuggestions: [NamedLocation] = []
    public private(set) var pickup: NamedLocation?
    public private(set) var stops: [NamedLocation] = []
    public private(set) var dropoff: NamedLocation?
    /// Last load failure; cleared when the next load starts.
    public private(set) var errorMessage: String?
    public var isPickingStop = false
    public var isSearchingPickup = false
    public var isSearchingDropoff = false
    public var isSearchingStop = false

    public let savedPlaces: [SavedPlace]

    @ObservationIgnored private let vehicleType: VehicleType
    @ObservationIgnored private let repository: IBookingRepository
    @ObservationIgnored private let onContinue: (RideRequestDraft) -> Void
    @ObservationIgnored private var hasLoadedPickupSuggestions = false
    @ObservationIgnored private var dropoffSuggestionsTask: Task<Void, Never>?
    /// Set only by the preview initializer: keeps the real loads from replacing the fake data.
    @ObservationIgnored private var isPreview = false

    public init(
        vehicleType: VehicleType,
        savedPlaces: [SavedPlace],
        repository: IBookingRepository = BookingRepository.makeDefault(),
        onContinue: @escaping (RideRequestDraft) -> Void
    ) {
        self.vehicleType = vehicleType
        self.savedPlaces = savedPlaces
        self.repository = repository
        self.onContinue = onContinue
    }

    /// Suggestions that are not already a stop or the chosen dropoff.
    public var stopCandidates: [NamedLocation] {
        dropoffSuggestions.filter { candidate in
            !stops.contains(candidate) && candidate.id != dropoff?.id
        }
    }

    /// False only when there is nothing to offer in the stop sheet at all.
    public var canAddStop: Bool {
        !(stopCandidates.isEmpty && savedPlaces.isEmpty)
    }

    /// Loads pickup suggestions once. If the load fails the flag is reset so coming back to the
    /// screen retries instead of leaving the list empty forever.
    public func didAppear() {
        guard !isPreview else { return }
        guard !hasLoadedPickupSuggestions else { return }
        hasLoadedPickupSuggestions = true
        Task {
            let succeeded = await run {
                self.pickupSuggestions = try await self.repository.nearbyPickupSuggestions()
            }
            if !succeeded { hasLoadedPickupSuggestions = false }
        }
    }

    /// Changing the pickup invalidates the old dropoff list, so it is cleared and reloaded. A
    /// slower earlier request is cancelled so it can't overwrite the newer list.
    public func didSelectPickup(_ location: NamedLocation) {
        pickup = location
        // The pickup can't also be a stop.
        stops.removeAll { $0.id == location.id }
        guard !isPreview else { return }
        dropoffSuggestions = []
        dropoffSuggestionsTask?.cancel()
        dropoffSuggestionsTask = Task {
            await run {
                let suggestions = try await self.repository.dropoffSuggestions(near: location)
                // Pickup may have changed again while waiting.
                guard !Task.isCancelled, self.pickup?.id == location.id else { return }
                self.dropoffSuggestions = suggestions
            }
        }
    }

    /// Ignores duplicates and anything equal to the pickup or dropoff.
    public func didAddStop(_ location: NamedLocation) {
        guard !stops.contains(location), location.id != dropoff?.id, location.id != pickup?.id else { return }
        stops.append(location)
    }

    public func didRemoveStop(_ location: NamedLocation) {
        stops.removeAll { $0.id == location.id }
    }

    /// Continues to the fare step right away. Needs a pickup and a dropoff different from it.
    public func didSelectDropoff(_ location: NamedLocation) {
        guard let pickup else { return }
        guard location.id != pickup.id else {
            errorMessage = String(localized: "Pickup and dropoff can't be the same place.")
            return
        }
        errorMessage = nil
        dropoff = location
        onContinue(RideRequestDraft(vehicleType: vehicleType, pickup: pickup, stops: stops, dropoff: location))
    }

    public func didTapAddStop() {
        isPickingStop = true
    }

    public func didTapSearchPickup() {
        isSearchingPickup = true
    }

    public func didTapSearchDropoff() {
        isSearchingDropoff = true
    }

    public func didTapSearchStop() {
        isPickingStop = false
        isSearchingStop = true
    }

    public func didPickStop(_ location: NamedLocation) {
        didAddStop(location)
        isPickingStop = false
    }

    public func didFindPickup(_ location: NamedLocation) {
        didSelectPickup(location)
        isSearchingPickup = false
    }

    public func didFindDropoff(_ location: NamedLocation) {
        didSelectDropoff(location)
        isSearchingDropoff = false
    }

    public func didFindStop(_ location: NamedLocation) {
        didAddStop(location)
        isSearchingStop = false
    }

    /// Runs a load and shows its error. Returns false on failure. A cancelled load (superseded by a
    /// newer one) is not shown as an error.
    @discardableResult
    private func run(_ operation: @escaping () async throws -> Void) async -> Bool {
        errorMessage = nil
        do {
            try await operation()
            return true
        } catch {
            // A superseded load fails with a cancellation error; that is not worth showing.
            if Task.isCancelled || error is CancellationError { return false }
            errorMessage = (error as? BookingError) != nil ? String(localized: "Trip could not be found. Please try again.") : error.localizedDescription
            return false
        }
    }
}

#if DEBUG

extension LocationPickerViewModel {
    /// Preview state with fake suggestions. `hasPickup` reveals the Stops and Dropoff sections;
    /// `isError` shows the "same place" banner; `isEmptyView` has no suggestions at all.
    convenience init(
        isPreview: Bool = true,
        isError: Bool = false,
        isEmptyView: Bool = false,
        hasPickup: Bool = false,
        hasStop: Bool = false,
        savedPlaces: [SavedPlace] = []
    ) {
        self.init(vehicleType: .car, savedPlaces: savedPlaces, repository: MockBookingRepository(), onContinue: { _ in })
        self.isPreview = isPreview
        let suggestions: [NamedLocation] = isEmptyView ? [] : [.mockPickup(), .mockDropoff(), .mockStop()]
        pickupSuggestions = suggestions
        if hasPickup {
            pickup = .mockPickup()
            dropoffSuggestions = suggestions.filter { $0.id != pickup?.id }
        }
        if hasStop {
            stops = [.mockStop()]
        }
        if isError {
            errorMessage = "Pickup and dropoff can't be the same place."
        }
    }
}

#endif
