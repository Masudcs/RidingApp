import Foundation

/// What the fare step tells a Women Safe Mode rider about driver matching.
/// Banner shown on the fare step while a Women Safe Mode trip is being matched.
public enum WomenSafeNotice: Equatable, Sendable {
    /// Still looking for a female driver.
    case matching
    /// A non-female driver was assigned because none was available.
    case fallbackDriver
}
