import Testing
@testable import RidingApps
import Foundation

struct SessionTests {
    private func makeStore() -> (SessionStore, cleanup: () -> Void) {
        let service = "test.session.\(UUID().uuidString)"
        let suite = "test.defaults.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store = SessionStore(service: service, defaults: defaults)
        return (store, { store.clear(); defaults.removePersistentDomain(forName: suite) })
    }

    @Test func savingAndLoadingRoundTripsTheUser() throws {
        let (store, cleanup) = makeStore()
        defer { cleanup() }

        let user = AppUser(fullName: "Tania Ahmed", phoneNumber: "+8801700000000", role: .rider)
        #expect(store.save(user: user, driverVerification: nil))

        let restored = try #require(store.load())
        #expect(restored.user == user)
        #expect(restored.driverVerification == nil)
    }

    @Test func clearingRemovesTheSession() {
        let (store, cleanup) = makeStore()
        defer { cleanup() }

        store.save(user: AppUser(fullName: "Karim Rahman", phoneNumber: "+8801800000000", role: .driver),
                   driverVerification: nil)
        store.clear()

        #expect(store.load() == nil)
    }

    @Test func savingAgainOverwritesAndKeepsTokens() throws {
        let (store, cleanup) = makeStore()
        defer { cleanup() }

        let tokens = SessionTokens(accessToken: "a", refreshToken: "r", expiresAt: .now.addingTimeInterval(3600))
        var user = AppUser(fullName: "Tania", phoneNumber: "+8801700000000", role: .rider)
        store.save(user: user, driverVerification: nil, tokens: tokens)

        user.fullName = "Tania Ahmed"
        store.save(user: user, driverVerification: nil)

        #expect(try #require(store.load()).user.fullName == "Tania Ahmed")
        #expect(store.loadTokens() == tokens)
    }

    @Test func updatingTokensKeepsUserAndNeedsASession() throws {
        let (store, cleanup) = makeStore()
        defer { cleanup() }

        let fresh = SessionTokens(accessToken: "new", refreshToken: "r2", expiresAt: .now.addingTimeInterval(900))
        // No session saved yet: a late refresh must not recreate a login.
        #expect(!store.updateTokens(fresh))
        #expect(store.loadTokens() == nil)

        let user = AppUser(fullName: "Tania", phoneNumber: "+8801700000000", role: .rider)
        store.save(user: user, driverVerification: nil, tokens: SessionTokens(accessToken: "old", refreshToken: "r1", expiresAt: .now))
        #expect(store.updateTokens(fresh))
        #expect(store.loadTokens() == fresh)
        #expect(try #require(store.load()).user.id == user.id)
    }

    @Test func clearingTwiceIsHarmless() {
        let (store, cleanup) = makeStore()
        defer { cleanup() }
        store.clear()
        store.clear()
        #expect(store.load() == nil)
    }

    /// Uninstalling deletes `UserDefaults`, so a reinstall starts logged out.
    @Test func reinstallStartsLoggedOut() {
        let service = "test.session.\(UUID().uuidString)"
        let first = SessionStore(service: service, defaults: UserDefaults(suiteName: "a.\(UUID())")!)
        first.save(user: AppUser(fullName: "Old", phoneNumber: "+880", role: .rider), driverVerification: nil)

        // Brand-new UserDefaults == app reinstalled.
        let reinstalled = SessionStore(service: service, defaults: UserDefaults(suiteName: "b.\(UUID())")!)

        #expect(reinstalled.load() == nil)
    }

    /// Data that can't be decoded (e.g. written by an incompatible version) logs the user out
    /// and is removed instead of failing on every launch.
    @Test func unreadableDataIsClearedAndTreatedAsLoggedOut() {
        let service = "test.session.\(UUID().uuidString)"
        let suite = "test.defaults.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("not json".utf8), forKey: service)

        let store = SessionStore(service: service, defaults: defaults)

        #expect(store.load() == nil)
        #expect(defaults.data(forKey: service) == nil)
    }
}
