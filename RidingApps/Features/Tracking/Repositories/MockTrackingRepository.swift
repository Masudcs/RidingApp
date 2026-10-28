import Foundation

/// Demo tracking: plays a canned route (driver to pickup, then pickup to dropoff), one step every
/// 1.5s, then finishes the stream to signal trip completion.
public final class MockTrackingRepository: ITrackingRepository {
    private static let stepInterval: Duration = .milliseconds(1500)

    public init() {}

    public func streamDriverLocation(trip: Trip) -> AsyncStream<TripDriverInfo> {
        AsyncStream { continuation in
            let task = Task {
                let waypoints = Self.buildWaypoints(for: trip)
                for waypoint in waypoints {
                    if Task.isCancelled { break }
                    continuation.yield(waypoint)
                    try? await Task.sleep(for: Self.stepInterval)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Two legs in order: driver -> pickup (trip is not started), then pickup -> dropoff.
    private static func buildWaypoints(for trip: Trip) -> [TripDriverInfo] {
        let startDriver = trip.driver ?? syntheticDriver(near: trip)

        let toPickupSteps = stepCount(from: startDriver.currentLocation, to: trip.pickup.point, minSteps: 3, maxSteps: 6)
        let arrivalLeg = interpolate(
            driver: startDriver,
            from: startDriver.currentLocation,
            to: trip.pickup.point,
            steps: toPickupSteps,
            startEta: max(startDriver.etaMinutes, 1)
        )

        let averageSpeedMetersPerMinute = 400.0
        let rideDistance = trip.pickup.point.distance(to: trip.dropoff.point)
        let rideEtaMinutes = max(Int((rideDistance / averageSpeedMetersPerMinute).rounded(.up)), 1)
        let toDropoffSteps = stepCount(from: trip.pickup.point, to: trip.dropoff.point, minSteps: 4, maxSteps: 10)
        let inProgressLeg = interpolate(
            driver: arrivalLeg.last ?? startDriver,
            from: trip.pickup.point,
            to: trip.dropoff.point,
            steps: toDropoffSteps,
            startEta: rideEtaMinutes
        )

        return arrivalLeg + inProgressLeg
    }

    /// Straight-line steps from `start` to `end`; ETA counts down from `startEta` to 0 on the last step.
    private static func interpolate(
        driver: TripDriverInfo,
        from start: GeoPoint,
        to end: GeoPoint,
        steps: Int,
        startEta: Int
    ) -> [TripDriverInfo] {
        guard steps > 0 else { return [] }
        return (1...steps).map { step in
            let fraction = Double(step) / Double(steps)
            let remainingFraction = 1.0 - fraction
            let location = GeoPoint(
                latitude: start.latitude + (end.latitude - start.latitude) * fraction,
                longitude: start.longitude + (end.longitude - start.longitude) * fraction
            )
            let etaMinutes = step == steps ? 0 : max(Int((Double(startEta) * remainingFraction).rounded()), 1)
            return TripDriverInfo(
                driverId: driver.driverId,
                name: driver.name,
                ratingAverage: driver.ratingAverage,
                vehicleType: driver.vehicleType,
                vehiclePlate: driver.vehiclePlate,
                etaMinutes: etaMinutes,
                currentLocation: location
            )
        }
    }

    private static func stepCount(from start: GeoPoint, to end: GeoPoint, minSteps: Int, maxSteps: Int) -> Int {
        let distance = start.distance(to: end)
        let stepsFromDistance = Int((distance / 250).rounded(.up))
        return min(max(stepsFromDistance, minSteps), maxSteps)
    }

    /// Fallback when the trip has no driver attached yet.
    private static func syntheticDriver(near trip: Trip) -> TripDriverInfo {
        TripDriverInfo(
            driverId: "mock-driver",
            name: "Rahim Uddin",
            ratingAverage: 4.8,
            vehicleType: trip.vehicleType,
            vehiclePlate: "DHA-1234",
            etaMinutes: 5,
            currentLocation: GeoPoint(
                latitude: trip.pickup.point.latitude + 0.01,
                longitude: trip.pickup.point.longitude + 0.01
            )
        )
    }
}
