import Foundation
import MapKit
import UIKit

/// Deep-links out to the driver's preferred maps app for turn-by-turn navigation — this app
/// doesn't bundle its own routing engine, so getting a driver moving means handing off to
/// whichever app is installed, preferring Google Maps (common in Dhaka) over Apple Maps.
public enum MapsNavigation {
    /// Falls back to Apple Maps when Google Maps isn't installed. Checking `canOpenURL` for the
    /// `comgooglemaps` scheme requires it in Info.plist's `LSApplicationQueriesSchemes`; without it
    /// this always uses Apple Maps.
    @MainActor
    public static func openDirections(to destination: NamedLocation) {
        if let googleMapsURL = googleMapsURL(to: destination), UIApplication.shared.canOpenURL(googleMapsURL) {
            UIApplication.shared.open(googleMapsURL)
            return
        }

        let placemark = MKPlacemark(coordinate: destination.point.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = destination.title
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    private static func googleMapsURL(to destination: NamedLocation) -> URL? {
        URL(string: "comgooglemaps://?daddr=\(destination.point.latitude),\(destination.point.longitude)&directionsmode=driving")
    }
}
