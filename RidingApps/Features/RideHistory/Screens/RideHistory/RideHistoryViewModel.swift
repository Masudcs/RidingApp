import Foundation
import Observation

/// Picks which of the shared store's entries belong to the signed-in user.
@MainActor
@Observable
public final class RideHistoryViewModel {
    @ObservationIgnored private let userId: String

    public init(userId: String) {
        self.userId = userId
    }

    /// The user's own entries, most recent first. The screen passes in the shared store's entries
    /// so it re-renders whenever a trip is recorded.
    public func history(from entries: [RideHistoryEntry]) -> [RideHistoryEntry] {
        entries
            .filter { $0.ownerId == userId }
            .sorted { $0.completedAt > $1.completedAt }
    }
}
