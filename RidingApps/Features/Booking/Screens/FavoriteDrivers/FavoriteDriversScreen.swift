import SwiftUI

/// "My Drivers": lists favorite and blocked drivers; swipe to remove from either list.
public struct FavoriteDriversScreen: View {
    @State private var viewModel: FavoriteDriversViewModel

    public init(store: FavoriteDriversStore) {
        _viewModel = State(wrappedValue: FavoriteDriversViewModel(store: store))
    }

    public var body: some View {
        List {
            Section("Favorites") {
                if viewModel.favorites.isEmpty {
                    Text("No favorite drivers yet \u{2014} favorite a driver from your trip screen after a ride.")
                        .font(BrandTypography.caption)
                        .foregroundStyle(BrandColor.textSecondary)
                } else {
                    ForEach(viewModel.favorites) { driver in
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundStyle(BrandColor.accent)
                            Text(driver.name)
                        }
                    }
                    .onDelete { offsets in
                        viewModel.didDeleteFavorites(at: offsets)
                    }
                }
            }

            Section("Blocked") {
                if viewModel.blocked.isEmpty {
                    Text("No blocked drivers.")
                        .font(BrandTypography.caption)
                        .foregroundStyle(BrandColor.textSecondary)
                } else {
                    ForEach(viewModel.blocked) { driver in
                        HStack {
                            Image(systemName: "hand.raised.fill")
                                .foregroundStyle(BrandColor.danger)
                            Text(driver.name)
                        }
                    }
                    .onDelete { offsets in
                        viewModel.didDeleteBlocked(at: offsets)
                    }
                }
            }
        }
        .navigationTitle("My Drivers")
    }
}

#if DEBUG

#Preview("Favorites and blocked") {
    NavigationStack {
        FavoriteDriversScreen(store: .mock())
    }
}

#Preview("Empty") {
    NavigationStack {
        FavoriteDriversScreen(store: .mock(favorites: [:], blocked: [:]))
    }
}

#Preview("Favorites only") {
    NavigationStack {
        FavoriteDriversScreen(store: .mock(blocked: [:]))
    }
}

#Preview("Long names") {
    NavigationStack {
        FavoriteDriversScreen(store: .mock(
            favorites: ["drv-long-1": "Muhammad Abdur Rahman Chowdhury Al-Mamun Bin Karim"],
            blocked: ["drv-long-2": "Sheikh Mohammad Shahidullah Khondokar Jahangir Alam"]
        ))
    }
}

#endif
