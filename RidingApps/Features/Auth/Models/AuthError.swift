import Foundation

/// Errors the auth flow treats specially (everything else is shown as a generic failure).
public enum AuthError: Error, Sendable {
    /// The one-time code was wrong or expired; the user can retry.
    case invalidCode
}
