import Foundation

/// Shared the same way `RideHistoryStore` is: owned once by the root view and injected down, so a
/// place saved from the booking flow is immediately available next time without a round-trip.
/// Persisted to `UserDefaults`, keyed by rider, so saved places survive an app relaunch.
@MainActor
public final class SavedPlacesStore: ObservableObject {
    @Published public private(set) var places: [SavedPlace]

    private let storageKey: String
    private let defaults: UserDefaults

    public init(userId: String = "", defaults: UserDefaults = .standard) {
        self.storageKey = "savedPlaces.\(userId)"
        self.defaults = defaults
        self.places = LocalStore.load([SavedPlace].self, forKey: storageKey, defaults: defaults) ?? []
    }

    /// Blank labels (after trimming) are ignored.
    public func add(label: String, location: NamedLocation) {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        places.append(SavedPlace(label: trimmed, location: location))
        persist()
    }

    public func remove(id: String) {
        places.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        LocalStore.save(places, forKey: storageKey, defaults: defaults)
    }
}

#if DEBUG

// Preview stores use a throwaway user id and a separate UserDefaults suite, so a preview never
// reads or writes a real rider's saved data.

extension UserDefaults {
    /// Throwaway suite for Booking previews. Cleared on every call so each preview starts clean.
    static func bookingPreview() -> UserDefaults {
        let name = "RidingApps.booking.preview"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}

public extension SavedPlacesStore {
    static func mock(places: [SavedPlace] = SavedPlace.mockList()) -> SavedPlacesStore {
        let store = SavedPlacesStore(userId: "preview-user", defaults: .bookingPreview())
        for place in places {
            store.add(label: place.label, location: place.location)
        }
        return store
    }
}

#endif
