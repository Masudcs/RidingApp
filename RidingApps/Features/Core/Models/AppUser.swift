import Foundation

/// Which side of the marketplace an account is on; decides which root screen is shown.
public enum UserRole: String, Codable, Sendable {
    case rider
    case driver
}

/// Self-reported at onboarding; drives Women Safe Mode driver/rider matching. Never inferred.
public enum Gender: String, Codable, Sendable, CaseIterable {
    case female
    case male
    case undisclosed
}

/// The signed-in account (rider or driver). `ratingAverage`/`ratingCount` are server-owned
/// aggregates; the defaults (5.0, 0) are for new accounts.
public struct AppUser: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public var fullName: String
    public var phoneNumber: String
    public var role: UserRole
    public var profileImageURL: URL?
    public var ratingAverage: Double
    public var ratingCount: Int
    public var gender: Gender?
    /// Rider preference: request a female driver where available, with fallback if none is nearby.
    public var womenSafeModeEnabled: Bool

    public init(
        id: String = UUID().uuidString,
        fullName: String,
        phoneNumber: String,
        role: UserRole,
        profileImageURL: URL? = nil,
        ratingAverage: Double = 5.0,
        ratingCount: Int = 0,
        gender: Gender? = nil,
        womenSafeModeEnabled: Bool = false
    ) {
        self.id = id
        self.fullName = fullName
        self.phoneNumber = phoneNumber
        self.role = role
        self.profileImageURL = profileImageURL
        self.ratingAverage = ratingAverage
        self.ratingCount = ratingCount
        self.gender = gender
        self.womenSafeModeEnabled = womenSafeModeEnabled
    }
}

/// Driver-onboarding identity verification, checked before a driver can go online.
public struct DriverVerification: Equatable, Codable, Sendable {
    /// Where the driver is in the review process.
    public enum Status: String, Codable, Sendable {
        case notSubmitted
        case pending
        case verified
        case rejected
    }

    /// National ID number, sensitive: don't log it.
    public var nidNumber: String
    public var drivingLicenseNumber: String
    /// Only `.verified` lets a driver go online.
    public var status: Status
    public var vehicleType: VehicleType
    public var vehicleRegistrationPlate: String
    /// Set each time the quarterly automated background re-check completes; nil before the first run.
    public var lastRecheckedAt: Date?

    public init(
        nidNumber: String,
        drivingLicenseNumber: String,
        status: Status = .notSubmitted,
        vehicleType: VehicleType,
        vehicleRegistrationPlate: String,
        lastRecheckedAt: Date? = nil
    ) {
        self.nidNumber = nidNumber
        self.drivingLicenseNumber = drivingLicenseNumber
        self.status = status
        self.vehicleType = vehicleType
        self.vehicleRegistrationPlate = vehicleRegistrationPlate
        self.lastRecheckedAt = lastRecheckedAt
    }
}

/// Composite trust signal shown to riders: identity verification + recheck recency + rating history.
/// Each component is 0...1; `overall` is 0...100 for display.
public struct DriverTrustScore: Equatable, Sendable {
    public let verificationComponent: Double
    public let recencyComponent: Double
    public let ratingComponent: Double
    public let overall: Int

    public init(verificationComponent: Double, recencyComponent: Double, ratingComponent: Double) {
        self.verificationComponent = verificationComponent
        self.recencyComponent = recencyComponent
        self.ratingComponent = ratingComponent
        self.overall = Int(((verificationComponent * 0.5) + (recencyComponent * 0.2) + (ratingComponent * 0.3)) * 100)
    }
}

public extension DriverVerification {
    /// Weights: verification 50%, recheck recency 20%, rating 30%. Recency drops after 90 and 180 days.
    /// `now` is injectable so callers (and tests) don't depend on wall-clock time.
    func trustScore(ratingAverage: Double, now: Date) -> DriverTrustScore {
        let verificationComponent: Double = status == .verified ? 1.0 : (status == .pending ? 0.4 : 0.0)
        let recencyComponent: Double
        if let lastRecheckedAt {
            let days = now.timeIntervalSince(lastRecheckedAt) / 86400
            recencyComponent = days <= 90 ? 1.0 : (days <= 180 ? 0.6 : 0.25)
        } else {
            recencyComponent = 0.0
        }
        let ratingComponent = min(max(ratingAverage / 5.0, 0), 1)
        return DriverTrustScore(
            verificationComponent: verificationComponent,
            recencyComponent: recencyComponent,
            ratingComponent: ratingComponent
        )
    }
}

#if DEBUG

// Fixed fake data for SwiftUI previews. Debug builds only, so none of it ships.
// Defaults let a preview override just the field it is about.

public extension AppUser {
    /// A signed-in rider with a few trips behind them.
    static func mockRider(
        id: String = "rider-1",
        fullName: String = "Tania Ahmed",
        womenSafeModeEnabled: Bool = false
    ) -> AppUser {
        AppUser(
            id: id,
            fullName: fullName,
            phoneNumber: "+8801700000000",
            role: .rider,
            ratingAverage: 4.8,
            ratingCount: 36,
            gender: .female,
            womenSafeModeEnabled: womenSafeModeEnabled
        )
    }

    static func mockDriver(id: String = "driver-1", fullName: String = "Karim Rahman") -> AppUser {
        AppUser(
            id: id,
            fullName: fullName,
            phoneNumber: "+8801800000000",
            role: .driver,
            ratingAverage: 4.9,
            ratingCount: 212,
            gender: .male
        )
    }
}

public extension DriverVerification {
    static func mock(status: Status = .verified, vehicleType: VehicleType = .car) -> DriverVerification {
        DriverVerification(
            nidNumber: "1234567890",
            drivingLicenseNumber: "DL-123456",
            status: status,
            vehicleType: vehicleType,
            vehicleRegistrationPlate: "DHAKA-METRO-11-1234",
            lastRecheckedAt: status == .verified ? Date() : nil
        )
    }
}

#endif
