
/// Source of the driver's live position for a trip.
public protocol ITrackingRepository: Sendable {
    /// Yields driver updates until the trip is finished, then ends. The stream also ends when the
    /// consumer cancels, so callers must check cancellation before treating the end as "trip done".
    func streamDriverLocation(trip: Trip) -> AsyncStream<TripDriverInfo>
    /// Yields `true` after repeated poll failures and `false` once polling recovers. Starts with the current state.
    func connectionProblemStream() -> AsyncStream<Bool>
}

extension ITrackingRepository {
    /// Default for repositories that cannot lose a connection (mocks): never reports a problem.
    public func connectionProblemStream() -> AsyncStream<Bool> { .noConnectionProblem }
}
