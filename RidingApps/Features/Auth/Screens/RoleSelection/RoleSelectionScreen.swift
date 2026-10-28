import SwiftUI

/// Step 3: the user chooses to use the app as a rider or as a driver.
public struct RoleSelectionScreen: View {
    @State private var viewModel: RoleSelectionViewModel

    public init(onSelectRole: @escaping (UserRole) -> Void, viewModel: RoleSelectionViewModel? = nil) {
        _viewModel = State(wrappedValue: viewModel ?? RoleSelectionViewModel(onSelectRole: onSelectRole))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How will you use the app?")
                        .font(BrandTypography.largeTitle)
                        .foregroundStyle(BrandColor.textPrimary)
                    Text("You can change this later in settings.")
                        .font(BrandTypography.body)
                        .foregroundStyle(BrandColor.textSecondary)
                }

                Button {
                    viewModel.didTapRider()
                } label: {
                    RoleCard(
                        title: "I'm a Rider",
                        subtitle: "Book trips and get around the city.",
                        systemImage: "person.fill"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.didTapDriver()
                } label: {
                    RoleCard(
                        title: "I'm a Driver",
                        subtitle: "Earn money by giving rides.",
                        systemImage: "steeringwheel"
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .background(BrandColor.background)
    }
}

#if DEBUG

#Preview("Role selection") {
    NavigationStack {
        RoleSelectionScreen(onSelectRole: { _ in })
    }
}

#endif
