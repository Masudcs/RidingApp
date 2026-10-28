import Combine
import Foundation
import Observation

/// Manage saved places: pick a location via address search, name it in an alert, save it.
@MainActor @Observable
public final class SavedPlacesViewModel {
    public private(set) var places: [SavedPlace] = []
    public var isPickingLocation = false
    /// The location waiting for a label; the label alert is showing while this is non-nil.
    public private(set) var pendingLocation: NamedLocation?
    public var labelInput = ""

    @ObservationIgnored private let store: SavedPlacesStore
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    public init(store: SavedPlacesStore) {
        self.store = store
        self.places = store.places
        store.$places
            .sink { [weak self] places in self?.places = places }
            .store(in: &cancellables)
    }

    public func didTapAddPlace() {
        isPickingLocation = true
    }

    public func didPickLocation(_ location: NamedLocation) {
        pendingLocation = location
        isPickingLocation = false
    }

    public func didCancelPicking() {
        isPickingLocation = false
    }

    public func didTapSave() {
        if let pendingLocation {
            // A blank label would be dropped by the store and the chosen place silently lost,
            // so fall back to the place name.
            let trimmed = labelInput.trimmingCharacters(in: .whitespacesAndNewlines)
            store.add(label: trimmed.isEmpty ? pendingLocation.title : trimmed, location: pendingLocation)
        }
        didDismissLabelAlert()
    }

    public func didDismissLabelAlert() {
        labelInput = ""
        pendingLocation = nil
    }

    public func didDelete(at offsets: IndexSet) {
        // Collect ids first: each removal updates `places` synchronously and shifts later indices.
        let ids = offsets.compactMap { places.indices.contains($0) ? places[$0].id : nil }
        for id in ids {
            store.remove(id: id)
        }
    }
}

#if DEBUG

extension SavedPlacesViewModel {
    /// Preview state backed by a throwaway store. `isLabeling` shows the "Label this place" alert.
    convenience init(isPreview: Bool = true, isEmptyView: Bool = false, isLabeling: Bool = false) {
        self.init(store: .mock(places: isEmptyView ? [] : SavedPlace.mockList()))
        if isLabeling {
            pendingLocation = .mockStop()
            labelInput = "Office"
        }
    }
}

#endif
