import Foundation

/// Real tracking backend. Polls the driver-location endpoint (no push channel yet).
/// TODO(real API): swap polling for a live feed if the server offers one.
public final class TrackingRepository: ITrackingRepository {
    /// Endpoint paths, relative to the API base URL.
    private enum Paths {
        static func driverLocation(tripId: String) -> String { "trips/\(tripId.pathEscaped)/driver-location" }
    }

    /// `isTripCompleted` is the server's signal that the stream should end.
    private struct DriverLocationResponse: Decodable {
        let driver: TripDriverInfo
        let isTripCompleted: Bool
    }

    private let apiClient: APIClient
    private let backoff: PollBackoff
    private let monitor = ConnectionProblemMonitor()

    /// `backoff` sets the poll interval (its base delay) and the retry delays after failures.
    public init(
        apiClient: APIClient = APIClientFactory.make(),
        backoff: PollBackoff = PollBackoff(baseDelay: .seconds(3))
    ) {
        self.apiClient = apiClient
        self.backoff = backoff
    }

    public func connectionProblemStream() -> AsyncStream<Bool> {
        monitor.stream()
    }

    /// Polls the backend for the driver's position and finishes once the trip is reported complete.
    /// A failed poll is retried with exponential backoff and, after repeated failures,
    /// reported through `connectionProblemStream`; the stream does not end on errors, only on
    /// completion or cancellation.
    public func streamDriverLocation(trip: Trip) -> AsyncStream<TripDriverInfo> {
        let apiClient = apiClient
        let monitor = monitor
        let initialBackoff = backoff
        return AsyncStream { continuation in
            let task = Task {
                var backoff = initialBackoff
                while !Task.isCancelled {
                    do {
                        let response: DriverLocationResponse = try await apiClient.send(Endpoint(path: Paths.driverLocation(tripId: trip.id)))
                        backoff.recordSuccess()
                        monitor.update(hasProblem: false)
                        continuation.yield(response.driver)
                        if response.isTripCompleted { break }
                    } catch is CancellationError {
                        break
                    } catch {
                        backoff.recordFailure()
                        monitor.update(hasProblem: backoff.hasConnectionProblem)
                    }
                    try? await Task.sleep(for: backoff.currentDelay)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
