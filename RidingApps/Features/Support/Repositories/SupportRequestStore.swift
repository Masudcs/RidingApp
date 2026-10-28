import Foundation

/// Local cache of the requests the user has submitted (the backend is the source of truth), so the
/// history is visible offline. Persisted to `UserDefaults`, keyed by user, so submitted requests survive an app relaunch.
@MainActor
public final class SupportRequestStore: ObservableObject {
    @Published public private(set) var requests: [SupportRequest]

    private let storageKey: String
    private let defaults: UserDefaults

    public init(userId: String = "", defaults: UserDefaults = .standard) {
        self.storageKey = "supportRequests.\(userId)"
        self.defaults = defaults
        self.requests = LocalStore.load([SupportRequest].self, forKey: storageKey, defaults: defaults) ?? []
    }

    /// Newest first. Saved immediately, so the request survives a relaunch.
    public func submit(category: SupportRequestCategory, message: String) {
        record(SupportRequest(category: category, message: message))
    }

    /// Caches a request the backend has accepted. Newest first; saved immediately.
    public func record(_ request: SupportRequest) {
        requests.insert(request, at: 0)
        LocalStore.save(requests, forKey: storageKey, defaults: defaults)
    }
}
