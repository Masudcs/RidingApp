import Foundation

/// Fake network delay for mock repositories (0.25-0.65s).
public enum MockLatency {
    /// Sleeps for a short, randomized interval so mock-backed UIs still show loading states.
    public static func short() async {
        try? await Task.sleep(nanoseconds: UInt64.random(in: 250_000_000...650_000_000))
    }
}
