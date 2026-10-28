import MapKit

/// Map annotation data for the tracking map. `id` must stay stable per pin so the map moves it
/// instead of recreating it.
struct TrackingMapPin: Identifiable {
    /// What the pin marks. `.stop` holds the 1-based stop number.
    enum Kind {
        case pickup
        case dropoff
        case stop(Int)
        case driver(VehicleType)
    }

    let id: String
    let coordinate: CLLocationCoordinate2D
    let kind: Kind
}
