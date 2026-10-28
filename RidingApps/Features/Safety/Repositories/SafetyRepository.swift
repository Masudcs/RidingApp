import Foundation

/// API-backed `ISafetyRepository`. Errors from `APIClient` are passed through unchanged so the
/// caller can show them; nothing is retried here.
public final class SafetyRepository: ISafetyRepository {
    /// Endpoint paths, relative to the API base URL.
    private enum Paths {
        static let sos = "safety/sos"
        static let contacts = "safety/contacts"
        static let notifyContacts = "safety/contacts/notify"
        static func contact(id: String) -> String { "safety/contacts/\(id.pathEscaped)" }
    }

    /// Body for `safety/sos`.
    private struct TriggerSOSBody: Encodable {
        let tripId: String
        let role: UserRole
        let location: GeoPoint
    }

    /// Body for `safety/contacts/notify`.
    private struct NotifyContactsBody: Encodable {
        let tripId: String
        let location: GeoPoint
        let reason: String
    }

    /// For endpoints whose response body is ignored.
    private struct EmptyResponse: Decodable {}

    private let apiClient: APIClient

    public init(apiClient: APIClient = APIClientFactory.make()) {
        self.apiClient = apiClient
    }

    public func triggerSOS(tripId: String, role: UserRole, location: GeoPoint) async throws -> SOSAlert {
        let body = try JSONEncoder().encode(TriggerSOSBody(tripId: tripId, role: role, location: location))
        return try await apiClient.send(Endpoint(path: Paths.sos, method: .post, body: body))
    }

    public func fetchEmergencyContacts() async throws -> [EmergencyContact] {
        try await apiClient.send(Endpoint(path: Paths.contacts))
    }

    public func addEmergencyContact(_ contact: EmergencyContact) async throws {
        let body = try JSONEncoder().encode(contact)
        let _: EmptyResponse = try await apiClient.send(Endpoint(path: Paths.contacts, method: .post, body: body))
    }

    public func removeEmergencyContact(id: String) async throws {
        let _: EmptyResponse = try await apiClient.send(Endpoint(path: Paths.contact(id: id), method: .delete))
    }

    public func notifyEmergencyContacts(tripId: String, location: GeoPoint, reason: String) async throws {
        let body = try JSONEncoder().encode(NotifyContactsBody(tripId: tripId, location: location, reason: reason))
        let _: EmptyResponse = try await apiClient.send(Endpoint(path: Paths.notifyContacts, method: .post, body: body))
    }
}
