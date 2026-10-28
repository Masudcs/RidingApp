import Foundation

/// Fake demand data around Dhaka: random zones and intensities on every call, for offline use.
public actor MockDemandRepository: IDemandRepository {
    /// A fixed area and position that zones are generated from.
    private struct ZoneSeed {
        let label: String
        let latitude: Double
        let longitude: Double
    }

    private static let seeds: [ZoneSeed] = [
        ZoneSeed(label: "Gulshan 1", latitude: 23.7809, longitude: 90.4155),
        ZoneSeed(label: "Dhanmondi", latitude: 23.7461, longitude: 90.3742),
        ZoneSeed(label: "Bashundhara", latitude: 23.7509, longitude: 90.3925),
        ZoneSeed(label: "Motijheel", latitude: 23.7332, longitude: 90.4172),
        ZoneSeed(label: "Uttara", latitude: 23.8747, longitude: 90.3987),
        ZoneSeed(label: "Mirpur", latitude: 23.8223, longitude: 90.3654),
        ZoneSeed(label: "Banani", latitude: 23.7937, longitude: 90.4066),
        ZoneSeed(label: "Mohammadpur", latitude: 23.7656, longitude: 90.3589)
    ]

    private let logger = AppLogger(category: "Demand")

    public init() {}

    public func fetchDemandZones() async throws -> [DemandZone] {
        await MockLatency.short()

        let zoneCount = Int.random(in: 6...Self.seeds.count)
        let chosenSeeds = Self.seeds.shuffled().prefix(zoneCount)

        let zones = chosenSeeds.map { seed -> DemandZone in
            let intensity = DemandZone.Intensity.allCases.randomElement() ?? .low
            let tripsPerHour = Self.estimatedTripsPerHour(for: intensity)
            let jitterLatitude = seed.latitude + Double.random(in: -0.004...0.004)
            let jitterLongitude = seed.longitude + Double.random(in: -0.004...0.004)

            return DemandZone(
                id: "\(seed.label)-\(UUID().uuidString.prefix(8))",
                center: GeoPoint(latitude: jitterLatitude, longitude: jitterLongitude),
                intensity: intensity,
                label: seed.label,
                estimatedTripsPerHour: tripsPerHour
            )
        }

        logger.debug("Fetched \(zones.count) demand zones")
        return zones
    }

    private static func estimatedTripsPerHour(for intensity: DemandZone.Intensity) -> Int {
        switch intensity {
        case .low: return Int.random(in: 5...15)
        case .medium: return Int.random(in: 15...35)
        case .high: return Int.random(in: 35...70)
        }
    }
}
