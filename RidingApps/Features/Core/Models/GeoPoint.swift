import Foundation
import CoreLocation

/// Codable/Sendable wrapper around a coordinate so feature modules never need to import
/// CoreLocation just to pass a location across a boundary.
public struct GeoPoint: Equatable, Hashable, Codable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public init(coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }

    /// Great-circle distance in meters. Good enough for deviation checks; not for billing.
    public func distance(to other: GeoPoint) -> Double {
        let loc1 = CLLocation(latitude: latitude, longitude: longitude)
        let loc2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return loc1.distance(from: loc2)
    }
}

/// A `GeoPoint` with display text: `title` is the place name, `subtitle` the address or area.
/// Used for pickup, stops, dropoff and saved places.
public struct NamedLocation: Equatable, Hashable, Codable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let point: GeoPoint

    public init(id: String = UUID().uuidString, title: String, subtitle: String, point: GeoPoint) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.point = point
    }
}

#if DEBUG

// Fixed fake data for SwiftUI previews. Debug builds only, so none of it ships.
// Defaults let a preview override just the field it is about.

public extension GeoPoint {
    /// Gulshan 1, Dhaka.
    static let mockPickup = GeoPoint(latitude: 23.7806, longitude: 90.4163)
    /// Dhanmondi, Dhaka.
    static let mockDropoff = GeoPoint(latitude: 23.7461, longitude: 90.3742)
}

public extension NamedLocation {
    static func mockPickup() -> NamedLocation {
        NamedLocation(id: "pickup-1", title: "Gulshan 1", subtitle: "Gulshan Avenue, Dhaka", point: .mockPickup)
    }

    static func mockDropoff() -> NamedLocation {
        NamedLocation(id: "dropoff-1", title: "Dhanmondi 27", subtitle: "Road 27, Dhanmondi, Dhaka", point: .mockDropoff)
    }

    static func mockStop() -> NamedLocation {
        NamedLocation(
            id: "stop-1",
            title: "Farmgate",
            subtitle: "Farmgate, Dhaka",
            point: GeoPoint(latitude: 23.7561, longitude: 90.3872)
        )
    }
}

#endif
