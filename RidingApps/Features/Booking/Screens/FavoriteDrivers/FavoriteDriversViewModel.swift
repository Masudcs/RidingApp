import Combine
import Foundation
import Observation

/// Read-only mirror of `FavoriteDriversStore` as sorted rows, plus swipe-to-remove.
@MainActor @Observable
public final class FavoriteDriversViewModel {
    /// One driver in the favorites or blocked list.
    public struct DriverRow: Identifiable, Equatable {
        public let id: String
        public let name: String
    }

    public private(set) var favorites: [DriverRow] = []
    public private(set) var blocked: [DriverRow] = []

    @ObservationIgnored private let store: FavoriteDriversStore
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    public init(store: FavoriteDriversStore) {
        self.store = store
        store.$favorites
            .map { Self.rows(from: $0) }
            .sink { [weak self] rows in self?.favorites = rows }
            .store(in: &cancellables)
        store.$blocked
            .map { Self.rows(from: $0) }
            .sink { [weak self] rows in self?.blocked = rows }
            .store(in: &cancellables)
    }

    public func didDeleteFavorites(at offsets: IndexSet) {
        // Copy the rows first: each toggle updates `favorites` synchronously, which would shift
        // the remaining indices.
        let rows = offsets.compactMap { favorites.indices.contains($0) ? favorites[$0] : nil }
        for row in rows {
            store.toggleFavorite(driverId: row.id, name: row.name)
        }
    }

    public func didDeleteBlocked(at offsets: IndexSet) {
        let rows = offsets.compactMap { blocked.indices.contains($0) ? blocked[$0] : nil }
        for row in rows {
            store.toggleBlocked(driverId: row.id, name: row.name)
        }
    }

    private static func rows(from drivers: [String: String]) -> [DriverRow] {
        drivers.keys.sorted().map { DriverRow(id: $0, name: drivers[$0] ?? "") }
    }
}
