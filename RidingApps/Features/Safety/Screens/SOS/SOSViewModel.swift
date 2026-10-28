import Observation
import Foundation

/// State for the SOS button that floats over the active trip. Flow: tap -> confirmation dialog
/// -> `didConfirmTrigger` -> `triggerSOS` call -> banner shows the alert status, or an error.
/// Only one alert per screen is allowed; once `activeAlert` is set the button is disabled.
@MainActor
@Observable
public final class SOSViewModel {
    /// Drives the "Trigger emergency SOS?" confirmation dialog.
    public var isConfirming: Bool = false
    public private(set) var isTriggering: Bool = false
    /// The alert the backend created. Nil until the request succeeds.
    public private(set) var activeAlert: SOSAlert?
    /// Shown when the SOS request failed. The user has to tap again, nothing is retried automatically.
    public private(set) var errorMessage: String?

    private let tripId: String
    private let role: UserRole
    @ObservationIgnored private let repository: ISafetyRepository
    /// Set only by the debug preview initializer; SOS never reaches the repository or notifications.
    @ObservationIgnored private var isPreview = false

    public init(
        tripId: String,
        role: UserRole,
        repository: ISafetyRepository = AppEnvironment.current.usesMockServices ? MockSafetyRepository.shared : SafetyRepository()
    ) {
        self.tripId = tripId
        self.role = role
        self.repository = repository
    }

    public var isButtonDisabled: Bool {
        isTriggering || activeAlert != nil
    }

    public func statusDescription(for alert: SOSAlert) -> String {
        switch alert.status {
        case .triggered:
            return String(localized: "Alert sent")
        case .dispatcherNotified:
            return String(localized: "Dispatcher notified")
        case .resolved:
            return String(localized: "Resolved")
        case .falseAlarm:
            return String(localized: "Marked as false alarm")
        }
    }

    public func didTapSOS() {
        guard !isButtonDisabled else { return }
        isConfirming = true
    }

    public func didCancelConfirmation() {
        isConfirming = false
    }

    /// Sends the alert with the rider's location at the moment of confirmation.
    public func didConfirmTrigger(location: GeoPoint) {
        isConfirming = false
        guard !isPreview else { return }
        // A second confirm while a request is running or an alert exists must not send another SOS.
        guard !isButtonDisabled else { return }
        isTriggering = true
        errorMessage = nil
        Task {
            do {
                let alert = try await repository.triggerSOS(tripId: tripId, role: role, location: location)
                self.activeAlert = alert
                self.isTriggering = false
                Analytics.track("sos_triggered", ["role": role.rawValue])
                LocalNotifications.notify(
                    title: String(localized: "Emergency alert sent"),
                    body: String(localized: "Your trusted contacts and support have been notified of your location.")
                )
            } catch {
                self.errorMessage = error.localizedDescription
                self.isTriggering = false
            }
        }
    }
}

#if DEBUG

extension SOSViewModel {
    /// Fixed fake state. Idle by default; `isLoading` is a request in flight, `isError` a failed
    /// request, `isSent` an accepted alert.
    convenience init(isPreview: Bool = true, isLoading: Bool = false, isError: Bool = false, isSent: Bool = false) {
        self.init(tripId: "trip-1", role: .rider, repository: MockSafetyRepository())
        self.isPreview = isPreview
        self.isTriggering = isLoading
        self.errorMessage = isError ? String(localized: "Couldn't send the alert. Please try again.") : nil
        if isSent {
            self.activeAlert = SOSAlert(tripId: "trip-1", triggeredBy: .rider, location: .mockPickup, status: .dispatcherNotified)
        }
    }
}

#endif
