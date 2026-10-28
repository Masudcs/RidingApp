import Foundation

/// Keeps one idempotency key per user ACTION (not per HTTP attempt) for a view model.
///
/// Call `key(for:)` when the action starts: the same description returns the same key, so a retry
/// after a timeout is recognised by the server; a different description (e.g. another amount)
/// gets a new key. Call `reset()` once the action has a final outcome (success or a definite
/// refusal); keep it when the outcome is unknown (network error).
public struct IdempotencyKeyHolder: Sendable {
    private var current: (fingerprint: String, key: String)?

    public init() {}

    /// The key for the action described by `fingerprint` (include everything that defines it).
    public mutating func key(for fingerprint: String) -> String {
        if let current, current.fingerprint == fingerprint { return current.key }
        let key = UUID().uuidString
        current = (fingerprint, key)
        return key
    }

    /// Forgets the key so the next action gets a fresh one.
    public mutating func reset() {
        current = nil
    }

    /// The key currently held, if any (for tests).
    public var currentKey: String? { current?.key }
}
