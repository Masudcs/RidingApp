import Foundation
import os

/// Central logger so every module logs through the same subsystem, filterable in Console.app by
/// category (e.g. "Booking", "Tracking"). Verbose levels are suppressed automatically in Production
/// via `AppEnvironment.isVerboseLoggingEnabled`.
public struct AppLogger: Sendable {
    private let logger: Logger
    private let isVerboseLoggingEnabled: Bool

    /// `environment` is injectable so tests can force verbose logging on or off.
    public init(category: String, environment: AppEnvironment = .current) {
        self.logger = Logger(subsystem: "com.ridehailing.app", category: category)
        self.isVerboseLoggingEnabled = environment.isVerboseLoggingEnabled
    }

    /// Dropped outside Dev/Staging. Messages are logged `.public`, so never pass phone numbers,
    /// tokens or other personal data to any level.
    public func debug(_ message: String) {
        guard isVerboseLoggingEnabled else { return }
        logger.debug("\(message, privacy: .public)")
    }

    public func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    public func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}
