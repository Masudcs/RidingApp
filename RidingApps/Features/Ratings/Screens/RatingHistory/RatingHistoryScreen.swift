import SwiftUI

/// List of ratings other people left for this user (loading, error and empty states included).
public struct RatingHistoryScreen: View {
    @State private var viewModel: RatingHistoryViewModel

    public init(userId: String, viewModel: RatingHistoryViewModel? = nil) {
        _viewModel = State(wrappedValue: viewModel ?? RatingHistoryViewModel(userId: userId))
    }

    public var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .error(let message):
                ErrorBanner(message)
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            case .data(let ratings):
                if ratings.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "star.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(BrandColor.textSecondary)
                        Text("No ratings yet")
                            .font(BrandTypography.body)
                            .foregroundStyle(BrandColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(ratings) { rating in
                        RatingRow(rating: rating)
                    }
                    .listStyle(.plain)
                }
            }
        }
        .navigationTitle("Ratings")
        .task { await viewModel.load() }
    }
}

#if DEBUG

#Preview("Loading") {
    NavigationStack {
        RatingHistoryScreen(userId: "preview-user", viewModel: RatingHistoryViewModel(isLoading: true))
    }
}

#Preview("Data") {
    NavigationStack {
        RatingHistoryScreen(userId: "preview-user", viewModel: RatingHistoryViewModel())
    }
}

#Preview("Empty") {
    NavigationStack {
        RatingHistoryScreen(userId: "preview-user", viewModel: RatingHistoryViewModel(isEmptyView: true))
    }
}

#Preview("Error") {
    NavigationStack {
        RatingHistoryScreen(userId: "preview-user", viewModel: RatingHistoryViewModel(isError: true))
    }
}

#endif
