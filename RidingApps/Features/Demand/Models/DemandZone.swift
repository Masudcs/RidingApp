
/// A busy area on the driver's demand map.
public struct DemandZone: Identifiable, Equatable, Codable, Sendable {
    /// How busy the zone is.
    public enum Intensity: String, Codable, Sendable, CaseIterable {
        case low, medium, high
    }

    public let id: String
    /// Marker position; the zone is drawn as a pin, not a polygon.
    public let center: GeoPoint
    public let intensity: Intensity
    public let label: String
    /// Rough estimate for display only (shown as "~N trips/hour").
    public let estimatedTripsPerHour: Int

    public init(id: String, center: GeoPoint, intensity: Intensity, label: String, estimatedTripsPerHour: Int) {
        self.id = id
        self.center = center
        self.intensity = intensity
        self.label = label
        self.estimatedTripsPerHour = estimatedTripsPerHour
    }
}

#if DEBUG

// Fixed fake data for SwiftUI previews. Debug builds only, so none of it ships.
// Defaults let a preview override just the field it is about.

public extension DemandZone {
    static func mock(
        id: String = "zone-1",
        label: String = "Gulshan 1",
        intensity: Intensity = .high,
        estimatedTripsPerHour: Int = 48
    ) -> DemandZone {
        DemandZone(
            id: id,
            center: GeoPoint(latitude: 23.7809, longitude: 90.4155),
            intensity: intensity,
            label: label,
            estimatedTripsPerHour: estimatedTripsPerHour
        )
    }

    /// Zones of every intensity spread around Dhaka.
    static func mockList() -> [DemandZone] {
        [
            DemandZone(id: "zone-1", center: GeoPoint(latitude: 23.7809, longitude: 90.4155), intensity: .high, label: "Gulshan 1", estimatedTripsPerHour: 48),
            DemandZone(id: "zone-2", center: GeoPoint(latitude: 23.7461, longitude: 90.3742), intensity: .medium, label: "Dhanmondi", estimatedTripsPerHour: 24),
            DemandZone(id: "zone-3", center: GeoPoint(latitude: 23.8747, longitude: 90.3987), intensity: .low, label: "Uttara", estimatedTripsPerHour: 9),
            DemandZone(id: "zone-4", center: GeoPoint(latitude: 23.7332, longitude: 90.4172), intensity: .high, label: "Motijheel", estimatedTripsPerHour: 55),
            DemandZone(id: "zone-5", center: GeoPoint(latitude: 23.8223, longitude: 90.3654), intensity: .medium, label: "Mirpur", estimatedTripsPerHour: 30)
        ]
    }
}

#endif
