import Testing
@testable import RidingApps

@Test func mockServiceReturnsEnoughZonesWithinDhakaBounds() async throws {
    let service = MockDemandRepository()
    let zones = try await service.fetchDemandZones()

    #expect(zones.count >= 6)

    for zone in zones {
        #expect(zone.center.latitude >= 23.70 && zone.center.latitude <= 23.90)
        #expect(zone.center.longitude >= 90.35 && zone.center.longitude <= 90.45)
        #expect(zone.estimatedTripsPerHour > 0)
    }
}

@Test func estimatedTripsPerHourMatchesIntensityBand() async throws {
    let service = MockDemandRepository()
    let zones = try await service.fetchDemandZones()

    for zone in zones {
        switch zone.intensity {
        case .low:
            #expect((5...15).contains(zone.estimatedTripsPerHour))
        case .medium:
            #expect((15...35).contains(zone.estimatedTripsPerHour))
        case .high:
            #expect((35...70).contains(zone.estimatedTripsPerHour))
        }
    }
}
