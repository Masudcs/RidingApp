import Foundation

/// Pure geometry used to detect route deviation. Kept free of `TripTrackingViewModel` so it can be
/// unit tested directly without spinning up the mock location stream.
enum RouteDeviationMath {
    /// Perpendicular distance, in meters, from `point` to the line segment `segmentStart` ->
    /// `segmentEnd`.
    ///
    /// Latitude/longitude are projected onto a local meter-ish Cartesian plane (using the
    /// segment's own latitude to scale degrees-of-longitude) purely to find *where* along the
    /// segment the closest point falls. That flat-earth approximation is only ever used to pick
    /// the interpolation fraction `t` -- the reported distance itself still comes from
    /// `GeoPoint.distance(to:)`, which does a real geodesic calculation. At city scale the
    /// difference this makes to `t` is negligible, so we avoid hand-rolling Earth's radius.
    static func perpendicularDistanceMeters(
        from point: GeoPoint,
        segmentStart: GeoPoint,
        segmentEnd: GeoPoint
    ) -> Double {
        let referenceLatitudeRadians = segmentStart.latitude * .pi / 180
        let metersPerDegreeLatitude = 111_320.0
        let metersPerDegreeLongitude = 111_320.0 * cos(referenceLatitudeRadians)

        func localXY(_ candidate: GeoPoint) -> (x: Double, y: Double) {
            (x: candidate.longitude * metersPerDegreeLongitude, y: candidate.latitude * metersPerDegreeLatitude)
        }

        let start = localXY(segmentStart)
        let end = localXY(segmentEnd)
        let current = localXY(point)

        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy

        let t: Double
        if lengthSquared == 0 {
            t = 0
        } else {
            let rawT = ((current.x - start.x) * dx + (current.y - start.y) * dy) / lengthSquared
            t = min(max(rawT, 0), 1)
        }

        let closestPoint = GeoPoint(
            latitude: segmentStart.latitude + (segmentEnd.latitude - segmentStart.latitude) * t,
            longitude: segmentStart.longitude + (segmentEnd.longitude - segmentStart.longitude) * t
        )

        return point.distance(to: closestPoint)
    }
}
