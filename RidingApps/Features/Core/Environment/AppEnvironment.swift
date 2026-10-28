import Foundation

/// The three deployment tiers the app can run against. Selected at build time via the
/// `APP_ENVIRONMENT` Info.plist key, which is populated per-scheme from `Config/*.xcconfig`.
public enum AppEnvironment: String, CaseIterable, Sendable {
    case dev
    case staging
    case production

    /// Used when the key is missing or unrecognised (a misconfigured scheme). Debug builds fall back
    /// to `.dev` so development keeps working offline; release builds fall back to `.production`,
    /// so a broken config can never ship an app that silently runs on fake mock data.
    private static let fallback: AppEnvironment = {
        #if DEBUG
        return .dev
        #else
        return .production
        #endif
    }()

    public static var current: AppEnvironment {
        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: "APP_ENVIRONMENT") as? String,
            let env = AppEnvironment(rawValue: raw.lowercased())
        else {
            return fallback
        }
        return env
    }

    /// For debug/settings UI, not localised.
    public var displayName: String {
        switch self {
        case .dev: return "Dev"
        case .staging: return "Staging"
        case .production: return "Production"
        }
    }

    /// Base URL handed to `URLSessionAPIClient`. The force unwraps are on constant literals.
    public var apiBaseURL: URL {
        switch self {
        case .dev: return URL(string: "https://api.dev.ridehailing.app")!
        case .staging: return URL(string: "https://api.staging.ridehailing.app")!
        case .production: return URL(string: "https://api.ridehailing.app")!
        }
    }

    /// Dev/Staging run entirely against in-memory mock services until a real backend exists.
    /// Flip this once `URLSessionAPIClient` has real endpoints to call.
    public var usesMockServices: Bool {
        switch self {
        case .dev, .staging: return true
        case .production: return false
        }
    }

    /// Optional separate server used only for login. Set `AUTH_API_BASE_URL` in the environment's
    /// xcconfig (e.g. Config/Dev.xcconfig) to send real SMS codes while other features stay mocked.
    /// Nil when the key is missing or empty.
    public var authAPIBaseURL: URL? {
        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: "AUTH_API_BASE_URL") as? String,
            !raw.trimmingCharacters(in: .whitespaces).isEmpty
        else { return nil }
        return URL(string: raw.trimmingCharacters(in: .whitespaces))
    }

    /// Controls `AppLogger.debug`; off only in Production.
    public var isVerboseLoggingEnabled: Bool {
        self != .production
    }
}
