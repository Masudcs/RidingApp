import Foundation

/// A place the rider named ("Home", "Work") so it can be picked in one tap. Stored locally.
public struct SavedPlace: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let label: String
    public let location: NamedLocation

    public init(id: String = UUID().uuidString, label: String, location: NamedLocation) {
        self.id = id
        self.label = label
        self.location = location
    }
}

#if DEBUG

// Fixed fake data for SwiftUI previews. Debug builds only, so none of it ships.
// Defaults let a preview override just the field it is about.

public extension SavedPlace {
    static func mock(id: String = "place-1", label: String = "Home", location: NamedLocation = .mockPickup()) -> SavedPlace {
        SavedPlace(id: id, label: label, location: location)
    }

    static func mockList() -> [SavedPlace] {
        [
            .mock(id: "place-1", label: "Home", location: .mockPickup()),
            .mock(id: "place-2", label: "Work", location: .mockDropoff())
        ]
    }

    /// Overlong label and place name, to check truncation.
    static func mockLongText() -> SavedPlace {
        .mock(
            id: "place-long",
            label: "My grandmother's house near the old Dhaka market",
            location: NamedLocation(
                id: "long-1",
                title: "Bangabandhu International Conference Center, Agargaon Administrative Area",
                subtitle: "Sher-e-Bangla Nagar, Dhaka",
                point: .mockDropoff
            )
        )
    }
}

#endif
