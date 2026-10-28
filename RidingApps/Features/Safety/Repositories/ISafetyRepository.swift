
/// Backend access for safety features: SOS alerts and the rider's emergency contacts.
/// `SafetyRepository` talks to the API; `MockSafetyRepository` is used when mock services are on.
/// Callers must treat a thrown error as "not delivered" and tell the user, never as success.
public protocol ISafetyRepository: Sendable {
    /// Raises a full emergency alert for the trip. Returns the alert the backend created.
    func triggerSOS(tripId: String, role: UserRole, location: GeoPoint) async throws -> SOSAlert
    /// The current user's saved contacts.
    func fetchEmergencyContacts() async throws -> [EmergencyContact]
    func addEmergencyContact(_ contact: EmergencyContact) async throws
    func removeEmergencyContact(id: String) async throws
    /// Lighter-weight than `triggerSOS` — used for route-deviation/stall alerts, which warrant
    /// telling a contact something looks off without dispatching a full emergency response.
    func notifyEmergencyContacts(tripId: String, location: GeoPoint, reason: String) async throws
}
