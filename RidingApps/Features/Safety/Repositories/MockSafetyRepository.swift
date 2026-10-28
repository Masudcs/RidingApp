import Foundation

/// In-memory `ISafetyRepository` for mock mode. Nothing leaves the device; SOS and contact
/// notifications are only logged. Contacts live for the app session only.
public actor MockSafetyRepository: ISafetyRepository {
    /// Shared so contacts added on the Emergency Contacts screen are the ones route-deviation
    /// alerts notify.
    public static let shared = MockSafetyRepository()

    private var contacts: [EmergencyContact]
    private let logger = AppLogger(category: "Safety")

    public init() {
        self.contacts = [
            EmergencyContact(name: "Family Contact", phoneNumber: "+8801700000000")
        ]
    }

    public func triggerSOS(tripId: String, role: UserRole, location: GeoPoint) async throws -> SOSAlert {
        await MockLatency.short()
        let alert = SOSAlert(
            tripId: tripId,
            triggeredBy: role,
            location: location,
            status: .dispatcherNotified
        )
        logger.error("SOS triggered for trip \(tripId) by \(role.rawValue); dispatcher notified.")
        return alert
    }

    public func fetchEmergencyContacts() async throws -> [EmergencyContact] {
        await MockLatency.short()
        return contacts
    }

    public func addEmergencyContact(_ contact: EmergencyContact) async throws {
        await MockLatency.short()
        contacts.append(contact)
    }

    public func removeEmergencyContact(id: String) async throws {
        await MockLatency.short()
        contacts.removeAll { $0.id == id }
    }

    public func notifyEmergencyContacts(tripId: String, location: GeoPoint, reason: String) async throws {
        await MockLatency.short()
        guard !contacts.isEmpty else {
            logger.debug("Route-deviation alert for trip \(tripId) had no emergency contacts to notify.")
            return
        }
        logger.error("Notifying \(contacts.count) emergency contact(s) for trip \(tripId): \(reason)")
    }
}
