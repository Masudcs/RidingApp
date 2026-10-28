import Foundation
import os

/// Auth tokens issued by the backend after login.
/// Stored together with the session, so one `clear()` removes everything.
public struct SessionTokens: Codable, Equatable, Sendable {
    /// Short-lived token sent with every API request.
    public let accessToken: String
    /// Long-lived token used to get a new access token when the old one expires.
    public let refreshToken: String
    /// When the access token stops being valid.
    public let expiresAt: Date

    public init(accessToken: String, refreshToken: String, expiresAt: Date) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }

    /// True when the access token must be refreshed before calling the API.
    public var isExpired: Bool { expiresAt <= Date() }
}

/// Remembers the signed-in user so the app stays logged in after relaunch.
///
/// Where it is stored: `UserDefaults`, the same way the team's other apps do it. The whole session
/// (user, driver verification, tokens) is encoded to JSON and kept under ONE key. Uninstalling the
/// app deletes `UserDefaults`, so a reinstall always starts logged out and the user signs in again;
/// the backend remains the source of truth for everything else.
///
/// Trade-off to know about: `UserDefaults` is a plain file inside the app's sandbox, and it is
/// included in device backups. If tokens ever need stronger protection, only this class has to
/// change (the Keychain is the usual place); no caller would be affected.
///
/// How it is used (see `RootViewModel`):
/// - app launch       -> `load()`   restore the previous login
/// - login success    -> `save(...)` remember the login
/// - logout / account deleted / token refresh rejected (401) -> `clear()`
///
/// Safety rules built into this class:
/// - Stored data that can no longer be decoded (app update changed the models, or corruption)
///   is deleted, so the user is simply logged out instead of failing on every launch.
/// - Failures are logged (never the data itself) instead of silently ignored.
public final class SessionStore: @unchecked Sendable {
    /// Bump this when the stored format changes in a way old/new code can't read.
    private static let currentVersion = 1

    /// The `UserDefaults` key holding the session JSON. Different per test so tests don't collide.
    private let storageKey: String
    private let defaults: UserDefaults
    /// Makes load/save/clear safe if called from several threads at the same time.
    private let lock = NSLock()
    private let logger = Logger(subsystem: "com.ridehailing.app", category: "SessionStore")

    /// - Parameters:
    ///   - service: Name of the storage key. Inject a unique value in tests.
    ///   - defaults: Where the session is kept. Inject a throwaway suite in tests.
    public init(service: String = "com.ridehailing.app.session", defaults: UserDefaults = .standard) {
        self.storageKey = service
        self.defaults = defaults
    }

    /// The exact shape written to `UserDefaults` (as JSON).
    private struct StoredSession: Codable {
        /// Format version, lets future code reject data it doesn't understand.
        var version: Int
        var user: AppUser
        var driverVerification: DriverVerification?
        var tokens: SessionTokens?
    }

    // MARK: - Public API

    /// Returns the saved user (and driver verification), or `nil` if nobody is logged in
    /// or the saved data is unusable.
    public func load() -> (user: AppUser, driverVerification: DriverVerification?)? {
        guard let stored = loadStored() else { return nil }
        return (stored.user, stored.driverVerification)
    }

    /// Returns the saved API tokens, or `nil` if none were saved.
    public func loadTokens() -> SessionTokens? {
        loadStored()?.tokens
    }

    /// Saves the session. Returns `true` if it was written.
    /// Passing `tokens: nil` keeps any tokens already stored, so updating the profile
    /// (e.g. a name change) does not accidentally log the user out of the API.
    @discardableResult
    public func save(
        user: AppUser,
        driverVerification: DriverVerification?,
        tokens: SessionTokens? = nil
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        // Read the current tokens first so they can be preserved when `tokens` is nil.
        let existingTokens = defaults.data(forKey: storageKey).flatMap(decode)?.tokens
        let stored = StoredSession(
            version: Self.currentVersion,
            user: user,
            driverVerification: driverVerification,
            tokens: tokens ?? existingTokens
        )
        return write(stored)
    }

    /// Replaces only the tokens (after a refresh). Returns `false` and writes nothing when no
    /// session is saved, so a refresh that finishes after logout cannot bring the login back.
    @discardableResult
    public func updateTokens(_ tokens: SessionTokens) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard var stored = defaults.data(forKey: storageKey).flatMap(decode) else { return false }
        stored.tokens = tokens
        return write(stored)
    }

    /// Deletes the saved session. Safe to call even when nothing is saved.
    /// Call on logout and after the account is deleted on the server.
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        defaults.removeObject(forKey: storageKey)
    }

    // MARK: - Private

    /// Shared by `load()` and `loadTokens()`: reads the saved JSON and decodes it.
    private func loadStored() -> StoredSession? {
        lock.lock()
        defer { lock.unlock() }

        guard let data = defaults.data(forKey: storageKey) else { return nil } // nothing saved -> not logged in

        // If the data can't be decoded it is permanently unusable, so delete it to avoid
        // failing on every launch.
        guard let stored = decode(data) else {
            logger.error("Stored session is unreadable; clearing it")
            defaults.removeObject(forKey: storageKey)
            return nil
        }
        return stored
    }

    /// Decodes JSON into a session. Returns `nil` for corrupt data or data written by a
    /// newer app version than this code understands.
    private func decode(_ data: Data) -> StoredSession? {
        guard let stored = try? JSONDecoder().decode(StoredSession.self, from: data),
              stored.version <= Self.currentVersion else { return nil }
        return stored
    }

    private func write(_ stored: StoredSession) -> Bool {
        do {
            defaults.set(try JSONEncoder().encode(stored), forKey: storageKey)
            return true
        } catch {
            logger.error("Failed to save session: \(String(describing: error), privacy: .public)")
            return false
        }
    }
}
