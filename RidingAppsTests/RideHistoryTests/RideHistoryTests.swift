import Testing
@testable import RidingApps
import Foundation

@MainActor
@Test func recordedTripsAppearInOwnerHistoryOnly() async throws {
    let suiteName = "test.rideHistory.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = RideHistoryStore(defaults: defaults)

    store.record(RideHistoryEntry(
        ownerId: "rider-1",
        tripId: "trip-1",
        role: .rider,
        counterpartName: "Karim Rahman",
        vehicleType: .car,
        pickupTitle: "Gulshan 1 Circle",
        dropoffTitle: "Dhanmondi 27",
        fare: .bdt(250),
        status: .completed
    ))
    store.record(RideHistoryEntry(
        ownerId: "driver-1",
        tripId: "trip-1",
        role: .driver,
        counterpartName: "Tania Ahmed",
        vehicleType: .car,
        pickupTitle: "Gulshan 1 Circle",
        dropoffTitle: "Dhanmondi 27",
        fare: .bdt(250),
        status: .completed
    ))

    #expect(store.history(forUserId: "rider-1").count == 1)
    #expect(store.history(forUserId: "rider-1")[0].role == .rider)
    #expect(store.history(forUserId: "driver-1").count == 1)
    #expect(store.history(forUserId: "nobody").isEmpty)
}

@MainActor
@Test func historyIsMostRecentFirst() async throws {
    let suiteName = "test.rideHistory.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = RideHistoryStore(defaults: defaults)
    let older = RideHistoryEntry(
        ownerId: "rider-2",
        tripId: "trip-older",
        role: .rider,
        counterpartName: "Selim Mia",
        vehicleType: .bike,
        pickupTitle: "A",
        dropoffTitle: "B",
        fare: .bdt(50),
        status: .completed,
        completedAt: Date(timeIntervalSince1970: 1_000)
    )
    let newer = RideHistoryEntry(
        ownerId: "rider-2",
        tripId: "trip-newer",
        role: .rider,
        counterpartName: "Rafiq Islam",
        vehicleType: .bike,
        pickupTitle: "C",
        dropoffTitle: "D",
        fare: .bdt(60),
        status: .completed,
        completedAt: Date(timeIntervalSince1970: 2_000)
    )

    store.record(older)
    store.record(newer)

    let history = store.history(forUserId: "rider-2")
    #expect(history.map(\.tripId) == ["trip-newer", "trip-older"])
}

@MainActor
@Test func recordingTheSameTripTwiceForAnOwnerIsIgnored() async throws {
    let suiteName = "test.rideHistory.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = RideHistoryStore(defaults: defaults)
    func entry(owner: String) -> RideHistoryEntry {
        RideHistoryEntry(
            ownerId: owner,
            tripId: "trip-dup",
            role: .rider,
            counterpartName: "Karim Rahman",
            vehicleType: .car,
            pickupTitle: "A",
            dropoffTitle: "B",
            fare: .bdt(100),
            status: .completed
        )
    }

    store.record(entry(owner: "rider-1"))
    store.record(entry(owner: "rider-1"))
    store.record(entry(owner: "rider-2"))

    #expect(store.history(forUserId: "rider-1").count == 1)
    #expect(store.history(forUserId: "rider-2").count == 1)
}
