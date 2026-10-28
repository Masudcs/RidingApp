import Foundation
import UserNotifications

/// By default iOS hides notifications while the app is open. This delegate overrides that so the
/// banner and sound still appear when the user is inside the app (e.g. a chat message arrives
/// while they're on the tracking screen).
private final class ForegroundPresenter: NSObject, UNUserNotificationCenterDelegate {
    /// iOS calls this when a notification arrives while the app is in the foreground.
    /// We answer with how to show it: a banner plus sound.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

/// Shows on-device notifications for ride events (ride matched, driver arriving, chat, SOS).
/// There's no real backend to send push from, so events schedule an immediate local notification
/// instead — same on-device UX as a push, no APNs needed.
/// When the real API is added, remote push (APNs) will be needed to notify users while the app
/// is closed; local notifications only fire from code that is running on the device.
public enum LocalNotifications {
    /// Kept in a static property because `UNUserNotificationCenter.delegate` is a weak reference;
    /// without this the presenter would be deallocated and foreground banners would stop working.
    private static let presenter = ForegroundPresenter()

    /// Call once at app start (see `RootScreen`). Registers the foreground presenter and shows
    /// the system permission prompt. If the user declines, `notify` silently shows nothing.
    public static func requestAuthorization() {
        UNUserNotificationCenter.current().delegate = presenter
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        }
    }

    /// Shows a notification immediately.
    /// - Parameter identifier: pass a fixed value to replace an earlier notification with the
    ///   same id instead of stacking a new one; the default (random) always creates a new one.
    public static func notify(title: String, body: String, identifier: String = UUID().uuidString) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        // `trigger: nil` means "deliver right now" rather than at a later time or place.
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
