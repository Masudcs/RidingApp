import SwiftUI

/// Full-screen prompt to rate the other party after a trip. Build it with trip/user ids; the
/// `viewModel` parameter exists only so tests and previews can inject one. `onDone` fires on
/// submit, skip, or when there is nobody to rate.
public struct RateTripScreen: View {
    @State private var viewModel: RateTripViewModel

    public init(
        tripId: String,
        raterId: String,
        raterRole: UserRole,
        ratedUserId: String,
        ratedUserName: String,
        onDone: @escaping () -> Void,
        viewModel: RateTripViewModel? = nil
    ) {
        _viewModel = State(wrappedValue: viewModel ?? RateTripViewModel(
            tripId: tripId,
            raterId: raterId,
            raterRole: raterRole,
            ratedUserId: ratedUserId,
            ratedUserName: ratedUserName,
            onDone: onDone
        ))
    }

    public var body: some View {
        @Bindable var viewModel = viewModel
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(BrandColor.primary)
                Text("Rate \(viewModel.ratedUserName)")
                    .font(BrandTypography.title)
                Text(viewModel.promptText)
                    .font(BrandTypography.body)
                    .foregroundStyle(BrandColor.textSecondary)
            }

            StarRatingView(stars: viewModel.stars) { viewModel.didSelectStars($0) }

            if !viewModel.suggestedTags.isEmpty {
                RatingTagFlowView(
                    tags: viewModel.suggestedTags,
                    selected: viewModel.selectedTags,
                    onToggle: { viewModel.didToggleTag($0) }
                )
            }

            TextField("Add a comment (optional)", text: $viewModel.comment, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...5)

            if let errorMessage = viewModel.errorMessage {
                ErrorBanner(errorMessage)
            }

            VStack(spacing: 12) {
                PrimaryButton("Submit rating", isLoading: viewModel.isSubmitting) {
                    viewModel.didTapSubmit()
                }
                SecondaryButton("Skip") {
                    viewModel.didTapSkip()
                }
            }
        }
        .padding(24)
    }
}

#if DEBUG

@MainActor
private func previewRateTripScreen(_ viewModel: RateTripViewModel) -> some View {
    RateTripScreen(
        tripId: viewModel.tripId,
        raterId: viewModel.raterId,
        raterRole: viewModel.raterRole,
        ratedUserId: viewModel.ratedUserId,
        ratedUserName: viewModel.ratedUserName,
        onDone: {},
        viewModel: viewModel
    )
}

#Preview("Five stars") {
    previewRateTripScreen(RateTripViewModel())
}

#Preview("Selected tags") {
    previewRateTripScreen(RateTripViewModel(hasSelectedTags: true))
}

#Preview("One star") {
    previewRateTripScreen(RateTripViewModel(stars: 1, hasSelectedTags: true))
}

#Preview("Rating a rider") {
    previewRateTripScreen(RateTripViewModel(raterRole: .driver))
}

#Preview("Submitting") {
    previewRateTripScreen(RateTripViewModel(isLoading: true))
}

#Preview("Error") {
    previewRateTripScreen(RateTripViewModel(isError: true))
}

#Preview("Long comment") {
    previewRateTripScreen(RateTripViewModel(hasLongText: true))
}

#endif
