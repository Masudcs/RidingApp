import Foundation
import CoreLocation
import Observation

/// Wraps CLLocationManager so feature modules never import CoreLocation directly. Consumers that
/// want the device's real position (Booking's "use current location", Safety's SOS) read
/// `currentLocation` and fall back to trip-derived coordinates while it's nil (permission not yet
/// granted, or no fix yet).
///
/// One instance is created in `RootScreen` and shared with the rider and driver flows.
/// Typical flow:
/// 1. `requestPermission()` at app start shows the system prompt (first time only).
/// 2. Once the user allows, the delegate starts updates automatically.
/// 3. Screens may call `startUpdating()` / `stopUpdating()` (e.g. home screens on appear).
/// 4. `currentLocation` always holds the latest good fix, or nil if there is none.
///
/// Requires `NSLocationWhenInUseUsageDescription` in Info.plist (already present).
/// Only "while in use" permission is requested, so updates stop when the app is backgrounded.
@MainActor
@Observable
public final class LocationProvider: NSObject {
    /// Simplified view of `CLAuthorizationStatus` so callers don't need to import CoreLocation.
    public enum AuthorizationState: Sendable {
        /// User hasn't been asked yet.
        case notDetermined
        /// Blocked by device policy (e.g. parental controls); the user can't change it in the app.
        case restricted
        /// User refused (or turned location off). Send them to Settings to change it.
        case denied
        /// Allowed (while-in-use or always).
        case authorized
    }

    /// Latest valid device position, or nil when permission isn't granted or there's no fix yet.
    /// Cleared if permission is revoked so a stale position is never used (e.g. for SOS).
    public private(set) var currentLocation: GeoPoint?
    public private(set) var authorizationState: AuthorizationState

    @ObservationIgnored private let manager: CLLocationManager

    /// Fixes older than this are ignored. iOS can hand over a cached location from minutes ago
    /// right after start, which would put the rider at an old position.
    @ObservationIgnored private let maxFixAge: TimeInterval = 15

    public override init() {
        manager = CLLocationManager()
        authorizationState = Self.map(manager.authorizationStatus)
        super.init()
        manager.delegate = self
        // 100 m is enough for choosing a pickup and saves battery.
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // Don't wake the app for movements under 25 m; fewer updates, less battery and less UI churn.
        manager.distanceFilter = 25
        manager.activityType = .automotiveNavigation
    }

    /// Shows the system permission prompt. Does nothing if the user has already answered,
    /// so it is safe to call every launch.
    public func requestPermission() {
        guard authorizationState == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    /// Starts location updates. Ignored until permission is granted; once it is,
    /// the delegate starts updates by itself. Calling it repeatedly is harmless.
    public func startUpdating() {
        guard authorizationState == .authorized else { return }
        manager.startUpdatingLocation()
    }

    public func stopUpdating() {
        manager.stopUpdatingLocation()
    }

    private static func map(_ status: CLAuthorizationStatus) -> AuthorizationState {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorizedAlways, .authorizedWhenInUse: return .authorized
        @unknown default: return .denied
        }
    }
}

extension LocationProvider: CLLocationManagerDelegate {
    /// Called when the user answers the prompt, and whenever they change the permission in Settings.
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationState = Self.map(manager.authorizationStatus)
        if authorizationState == .authorized {
            manager.startUpdatingLocation()
        } else {
            // Permission lost: stop tracking and forget the old position.
            manager.stopUpdatingLocation()
            currentLocation = nil
        }
    }

    /// Called with new fixes (oldest first). Keeps the newest one that is usable.
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last(where: isUsable) else { return }
        currentLocation = GeoPoint(coordinate: location.coordinate)
    }

    /// A fix is usable if it's valid and recent. A negative `horizontalAccuracy`
    /// means CoreLocation couldn't determine the position.
    private func isUsable(_ location: CLLocation) -> Bool {
        location.horizontalAccuracy >= 0 && abs(location.timestamp.timeIntervalSinceNow) <= maxFixAge
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        AppLogger(category: "Location").debug("Location update failed: \(error.localizedDescription)")
    }
}
