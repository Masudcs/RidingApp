import SwiftUI

/// Step 4: the user states their gender (used for Women Safe Mode matching) and, if a rider,
/// can turn Women Safe Mode on. `role` decides whether that toggle is shown.
public struct ProfileDetailsScreen: View {
    @State private var viewModel: ProfileDetailsViewModel

    /// - Parameters:
    ///   - initialGender: previously chosen gender, if the user came back to this step.
    ///   - initialWomenSafeMode: previously chosen Women Safe Mode value.
    public init(
        role: UserRole?,
        initialGender: Gender? = nil,
        initialWomenSafeMode: Bool = false,
        onContinue: @escaping (Gender, Bool) -> Void,
        viewModel: ProfileDetailsViewModel? = nil
    ) {
        _viewModel = State(wrappedValue: viewModel ?? ProfileDetailsViewModel(
            role: role,
            initialGender: initialGender,
            initialWomenSafeMode: initialWomenSafeMode,
            onContinue: onContinue
        ))
    }

    public var body: some View {
        @Bindable var viewModel = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tell us about yourself")
                        .font(BrandTypography.largeTitle)
                        .foregroundStyle(BrandColor.textPrimary)
                    Text("This helps us personalize your safety preferences.")
                        .font(BrandTypography.body)
                        .foregroundStyle(BrandColor.textSecondary)
                }

                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(errorMessage)
                }

                VStack(spacing: 12) {
                    ForEach(Gender.allCases, id: \.self) { gender in
                        Button {
                            viewModel.didSelectGender(gender)
                        } label: {
                            GenderOptionCard(
                                title: viewModel.title(for: gender),
                                systemImage: viewModel.systemImage(for: gender),
                                isSelected: viewModel.selectedGender == gender
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if viewModel.showsWomenSafeMode {
                    SectionCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Enable Women Safe Mode", isOn: $viewModel.womenSafeModeEnabled)
                                .font(BrandTypography.headline)
                                .foregroundStyle(BrandColor.textPrimary)
                                .tint(BrandColor.primary)
                            Text("We'll prioritize matching you with a female driver when available.")
                                .font(BrandTypography.caption)
                                .foregroundStyle(BrandColor.textSecondary)
                        }
                    }
                }

                PrimaryButton("Continue", isLoading: false, isEnabled: viewModel.canContinue) {
                    viewModel.didTapContinue()
                }
            }
            .padding(20)
        }
        .background(BrandColor.background)
    }
}

#if DEBUG

#Preview("Rider, nothing selected") {
    NavigationStack {
        ProfileDetailsScreen(
            role: .rider,
            onContinue: { _, _ in },
            viewModel: ProfileDetailsViewModel(isPreview: true, role: .rider)
        )
    }
}

#Preview("Rider, Women Safe Mode on") {
    NavigationStack {
        ProfileDetailsScreen(
            role: .rider,
            onContinue: { _, _ in },
            viewModel: ProfileDetailsViewModel(isPreview: true, role: .rider, gender: .female, womenSafeModeEnabled: true)
        )
    }
}

#Preview("Driver, gender selected") {
    NavigationStack {
        ProfileDetailsScreen(
            role: .driver,
            onContinue: { _, _ in },
            viewModel: ProfileDetailsViewModel(isPreview: true, role: .driver, gender: .male)
        )
    }
}

#Preview("Error") {
    NavigationStack {
        ProfileDetailsScreen(
            role: .rider,
            onContinue: { _, _ in },
            viewModel: ProfileDetailsViewModel(isPreview: true, role: .rider, errorMessage: "Please select an option.")
        )
    }
}

#endif
