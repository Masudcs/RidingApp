import Foundation
import Testing
@testable import RidingApps

@Test func driverLocationStreamHasNonIncreasingETAAtStart() async {
    let pickup = NamedLocation(title: "Gulshan 1", subtitle: "Dhaka", point: GeoPoint(latitude: 23.7808, longitude: 90.4177))
    let dropoff = NamedLocation(title: "Banani", subtitle: "Dhaka", point: GeoPoint(latitude: 23.7937, longitude: 90.4066))
    let trip = Trip(
        vehicleType: .car,
        pickup: pickup,
        dropoff: dropoff,
        suggestedFare: .bdt(150)
    )

    let service = MockTrackingRepository()
    var etaValues: [Int] = []

    for await info in service.streamDriverLocation(trip: trip) {
        etaValues.append(info.etaMinutes)
        if etaValues.count == 3 { break }
    }

    #expect(etaValues.count == 3)
    for index in 1..<etaValues.count {
        #expect(etaValues[index] <= etaValues[index - 1])
    }
}

@Test func perpendicularDistanceIsNearZeroForPointOnSegment() {
    let start = GeoPoint(latitude: 23.7808, longitude: 90.4177)
    let end = GeoPoint(latitude: 23.7937, longitude: 90.4066)
    let midpoint = GeoPoint(
        latitude: (start.latitude + end.latitude) / 2,
        longitude: (start.longitude + end.longitude) / 2
    )

    let distance = RouteDeviationMath.perpendicularDistanceMeters(
        from: midpoint,
        segmentStart: start,
        segmentEnd: end
    )

    #expect(distance < 1)
}

@Test func perpendicularDistanceMatchesExpectedOffsetForPointFarFromSegment() {
    let start = GeoPoint(latitude: 23.7808, longitude: 90.4177)
    let end = GeoPoint(latitude: 23.7808, longitude: 90.4277)
    let offRoutePoint = GeoPoint(latitude: 23.7863, longitude: 90.4227)

    let distance = RouteDeviationMath.perpendicularDistanceMeters(
        from: offRoutePoint,
        segmentStart: start,
        segmentEnd: end
    )

    #expect(distance > 500 && distance < 700)
}

@Test func sendingAMessageMakesItAppearInTheStream() async throws {
    let service = MockChatRepository()
    let sent = try await service.sendMessage(tripId: "trip-1", senderId: "rider-1", senderRole: .rider, text: "On my way!")

    #expect(sent.text == "On my way!")

    var received: ChatMessage?
    for await message in await service.messageStream(tripId: "trip-1") {
        received = message
        break
    }
    #expect(received?.id == sent.id)
}

@Test func sendingAnEmptyMessageThrows() async throws {
    let service = MockChatRepository()
    await #expect(throws: ChatError.emptyMessage) {
        _ = try await service.sendMessage(tripId: "trip-2", senderId: "rider-1", senderRole: .rider, text: "   ")
    }
}

// MARK: - Poll backoff and connection problems

@Test func pollBackoffDoublesUpToTheCapAndResetsOnSuccess() {
    var backoff = PollBackoff(baseDelay: .seconds(2), maxDelay: .seconds(30), failureThreshold: 3)
    #expect(backoff.currentDelay == .seconds(2))

    var delays: [Duration] = []
    for _ in 0..<6 {
        backoff.recordFailure()
        delays.append(backoff.currentDelay)
    }
    #expect(delays == [.seconds(2), .seconds(4), .seconds(8), .seconds(16), .seconds(30), .seconds(30)])
    #expect(backoff.hasConnectionProblem)

    backoff.recordSuccess()
    #expect(backoff.currentDelay == .seconds(2))
    #expect(!backoff.hasConnectionProblem)
}

@Test func pollBackoffReportsAProblemOnlyAfterTheThreshold() {
    var backoff = PollBackoff(failureThreshold: 3)
    backoff.recordFailure()
    backoff.recordFailure()
    #expect(!backoff.hasConnectionProblem)
    backoff.recordFailure()
    #expect(backoff.hasConnectionProblem)
}

/// Fails the first `failures` requests with a transport error, then answers with an empty list.
private final class FlakyAPIClient: APIClient, @unchecked Sendable {
    private let lock = NSLock()
    private var remainingFailures: Int

    init(failures: Int) {
        remainingFailures = failures
    }

    func send<Response: Decodable>(_ endpoint: Endpoint) async throws -> Response {
        lock.lock()
        let shouldFail = remainingFailures > 0
        if shouldFail { remainingFailures -= 1 }
        lock.unlock()
        if shouldFail { throw NetworkError.transport("offline") }
        guard let empty = [ChatMessage]() as? Response else { throw NetworkError.decoding("unexpected type") }
        return empty
    }
}

@Test func chatRepositoryReportsConnectionProblemAfterRepeatedFailuresAndRecovery() async {
    let fast = PollBackoff(baseDelay: .milliseconds(1), maxDelay: .milliseconds(4), failureThreshold: 3)
    let repository = ChatRepository(apiClient: FlakyAPIClient(failures: 4), backoff: fast)

    let polling = Task {
        for await _ in await repository.messageStream(tripId: "trip-1") {}
    }

    var states: [Bool] = []
    for await hasProblem in repository.connectionProblemStream() {
        states.append(hasProblem)
        if states.contains(true), hasProblem == false { break }
    }
    polling.cancel()

    #expect(states.contains(true))
    #expect(states.last == false)
}

// MARK: - Support requests

private struct FailingSupportRequestRepository: ISupportRequestRepository {
    func submitSupportRequest(category: SupportRequestCategory, message: String) async throws -> SupportRequest {
        throw NetworkError.server(statusCode: 500)
    }
}

@MainActor
@Test func supportCenterSubmitSendsToTheRepositoryAndCachesTheRequest() async throws {
    let repository = MockSupportRequestRepository()
    let defaults = UserDefaults(suiteName: "SupportTests-\(UUID().uuidString)")!
    let store = SupportRequestStore(userId: "u1", defaults: defaults)
    let viewModel = SupportCenterViewModel(userId: "u1", store: store, repository: repository)

    viewModel.message = "  Driver was late  "
    viewModel.didTapSubmit()
    #expect(viewModel.isSubmitting)
    #expect(!viewModel.canSubmit)

    for _ in 0..<200 where viewModel.isSubmitting { try await Task.sleep(for: .milliseconds(20)) }

    #expect(viewModel.didSubmit)
    #expect(viewModel.errorMessage == nil)
    #expect(viewModel.message.isEmpty)
    #expect(await repository.submitted.count == 1)
    #expect(await repository.submitted.first?.message == "Driver was late")
    #expect(store.requests.count == 1)
}

@MainActor
@Test func supportCenterSubmitFailureKeepsTheMessageAndShowsAnError() async throws {
    let defaults = UserDefaults(suiteName: "SupportTests-\(UUID().uuidString)")!
    let store = SupportRequestStore(userId: "u2", defaults: defaults)
    let viewModel = SupportCenterViewModel(userId: "u2", store: store, repository: FailingSupportRequestRepository())

    viewModel.message = "Charged twice"
    viewModel.didTapSubmit()
    for _ in 0..<200 where viewModel.isSubmitting { try await Task.sleep(for: .milliseconds(20)) }

    #expect(!viewModel.didSubmit)
    #expect(viewModel.errorMessage != nil)
    #expect(viewModel.message == "Charged twice")
    #expect(viewModel.canSubmit)
    #expect(store.requests.isEmpty)
}
