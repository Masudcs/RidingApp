import SwiftUI

/// Full-screen address search (shown as a sheet). `title` says what is being searched for.
public struct AddressSearchScreen: View {
    let title: String

    @State private var viewModel: AddressSearchViewModel

    public init(title: String, onSelect: @escaping (NamedLocation) -> Void, onCancel: @escaping () -> Void) {
        self.title = title
        _viewModel = State(wrappedValue: AddressSearchViewModel(onSelect: onSelect, onCancel: onCancel))
    }

    public var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            Group {
                if viewModel.query.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundStyle(BrandColor.textSecondary)
                        Text("Search for an address or place")
                            .font(BrandTypography.body)
                            .foregroundStyle(BrandColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.suggestions.isEmpty {
                    Text("No results")
                        .font(BrandTypography.body)
                        .foregroundStyle(BrandColor.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.suggestions) { suggestion in
                        Button {
                            viewModel.didSelect(suggestion)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.title)
                                    .font(BrandTypography.body)
                                    .foregroundStyle(BrandColor.textPrimary)
                                Text(suggestion.subtitle)
                                    .font(BrandTypography.caption)
                                    .foregroundStyle(BrandColor.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isResolving)
                    }
                    .listStyle(.plain)
                }
            }
            .overlay {
                if viewModel.isResolving {
                    ProgressView()
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(errorMessage)
                        .padding(16)
                }
            }
            .searchable(text: $viewModel.query, prompt: "Search for an address")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.didTapCancel() }
                }
            }
        }
    }
}

#if DEBUG

extension AddressSearchScreen {
    /// Preview-only: shows a ready-made view model.
    init(title: String, previewViewModel: AddressSearchViewModel) {
        self.title = title
        _viewModel = State(wrappedValue: previewViewModel)
    }
}

#Preview("Initial") {
    AddressSearchScreen(title: "Search Pickup", previewViewModel: AddressSearchViewModel(query: "", isEmptyView: true))
}

#Preview("Results") {
    AddressSearchScreen(title: "Search Pickup", previewViewModel: AddressSearchViewModel())
}

#Preview("No results") {
    AddressSearchScreen(title: "Search Pickup", previewViewModel: AddressSearchViewModel(query: "zzzz", isEmptyView: true))
}

#Preview("Resolving") {
    AddressSearchScreen(title: "Search Pickup", previewViewModel: AddressSearchViewModel(isLoading: true))
}

#Preview("Error") {
    AddressSearchScreen(title: "Search Pickup", previewViewModel: AddressSearchViewModel(isError: true))
}

#endif
