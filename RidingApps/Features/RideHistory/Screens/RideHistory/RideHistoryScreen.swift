import SwiftUI

/// The Profile tab's list of past trips, read from the shared `RideHistoryStore` so new trips
/// appear immediately.
public struct RideHistoryScreen: View {
    @State private var viewModel: RideHistoryViewModel
    private let store: RideHistoryStore

    public init(userId: String, store: RideHistoryStore, viewModel: RideHistoryViewModel? = nil) {
        self.store = store
        _viewModel = State(wrappedValue: viewModel ?? RideHistoryViewModel(userId: userId))
    }

    public var body: some View {
        let history = viewModel.history(from: store.entries)

        Group {
            if history.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundStyle(BrandColor.textSecondary)
                    Text("No rides yet")
                        .font(BrandTypography.body)
                        .foregroundStyle(BrandColor.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(history) { entry in
                    RideHistoryRow(entry: entry)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Ride History")
    }
}

#if DEBUG

#Preview("Data") {
    NavigationStack {
        RideHistoryScreen(userId: "preview-user", store: .mock())
    }
}

#Preview("Empty") {
    NavigationStack {
        RideHistoryScreen(userId: "preview-user", store: .mock(entries: []))
    }
}

#Preview("Long text") {
    NavigationStack {
        RideHistoryScreen(
            userId: "preview-user",
            store: .mock(entries: [
                .mock(
                    pickupTitle: "Bashundhara Residential Area, Block D, Road 12",
                    dropoffTitle: "Hazrat Shahjalal International Airport, Terminal 1"
                )
            ])
        )
    }
}

#endif
