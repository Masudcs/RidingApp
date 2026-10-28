import Foundation

/// Person notified on SOS or route deviation.
public struct EmergencyContact: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public var name: String
    public var phoneNumber: String

    public init(id: String = UUID().uuidString, name: String, phoneNumber: String) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
    }
}

/// Progress of an SOS: `.triggered` -> `.dispatcherNotified` -> `.resolved` or `.falseAlarm`.
public enum SOSAlertStatus: String, Codable, Sendable {
    case triggered
    case dispatcherNotified
    case resolved
    case falseAlarm
}

/// An SOS raised by the rider or driver during a trip, with where it happened.
public struct SOSAlert: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let tripId: String
    public let triggeredBy: UserRole
    public let location: GeoPoint
    public var status: SOSAlertStatus
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        tripId: String,
        triggeredBy: UserRole,
        location: GeoPoint,
        status: SOSAlertStatus = .triggered,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.tripId = tripId
        self.triggeredBy = triggeredBy
        self.location = location
        self.status = status
        self.createdAt = createdAt
    }
}

/// Emitted by Tracking as a trip progresses; the app target forwards it to Safety so an off-route
/// or stalled trip can notify emergency contacts without the rider having to press SOS themselves.
public struct RouteDeviationEvent: Equatable, Sendable {
    /// Why the event fired: the trip left its route, or the vehicle stopped moving.
    public enum Kind: Equatable, Sendable {
        case offRoute(distanceMeters: Double)
        case stalled(seconds: TimeInterval)
    }

    public let tripId: String
    public let location: GeoPoint
    public let kind: Kind
    public let detectedAt: Date

    public init(tripId: String, location: GeoPoint, kind: Kind, detectedAt: Date = Date()) {
        self.tripId = tripId
        self.location = location
        self.kind = kind
        self.detectedAt = detectedAt
    }
}

#if DEBUG

// Fixed fake data for SwiftUI previews. Debug builds only, so none of it ships.
// Defaults let a preview override just the field it is about.

public extension EmergencyContact {
    static func mockList() -> [EmergencyContact] {
        [
            EmergencyContact(id: "ec-1", name: "Rahim Ahmed", phoneNumber: "+8801711111111"),
            EmergencyContact(id: "ec-2", name: "Nasrin Akter", phoneNumber: "+8801722222222")
        ]
    }
}

#endif
