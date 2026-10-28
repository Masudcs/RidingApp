import SwiftUI

/// Lists the rider's saved places (swipe to delete) and lets them add one.
public struct SavedPlacesScreen: View {
    @State private var viewModel: SavedPlacesViewModel

    public init(store: SavedPlacesStore) {
        _viewModel = State(wrappedValue: SavedPlacesViewModel(store: store))
    }

    public var body: some View {
        @Bindable var viewModel = viewModel
        List {
            Section("Saved Places") {
                if viewModel.places.isEmpty {
                    Text("No saved places yet.")
                        .font(BrandTypography.caption)
                        .foregroundStyle(BrandColor.textSecondary)
                } else {
                    ForEach(viewModel.places) { place in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.label)
                                .font(BrandTypography.headline)
                            Text(place.location.title)
                                .font(BrandTypography.caption)
                                .foregroundStyle(BrandColor.textSecondary)
                        }
                    }
                    .onDelete { offsets in
                        viewModel.didDelete(at: offsets)
                    }
                }
            }

            Section {
                Button {
                    viewModel.didTapAddPlace()
                } label: {
                    Label("Add a Saved Place", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("Saved Places")
        .sheet(isPresented: $viewModel.isPickingLocation) {
            AddressSearchScreen(title: "Choose a Location", onSelect: { location in
                viewModel.didPickLocation(location)
            }, onCancel: {
                viewModel.didCancelPicking()
            })
        }
        .alert("Label this place", isPresented: Binding(
            get: { viewModel.pendingLocation != nil },
            set: { newValue in if !newValue { viewModel.didDismissLabelAlert() } }
        )) {
            TextField("e.g. Home, Work", text: $viewModel.labelInput)
            Button("Save") {
                viewModel.didTapSave()
            }
            Button("Cancel", role: .cancel) {
                viewModel.didDismissLabelAlert()
            }
        } message: {
            if let pendingLocation = viewModel.pendingLocation {
                Text(pendingLocation.title)
            }
        }
    }
}

#if DEBUG

extension SavedPlacesScreen {
    /// Preview-only: shows a ready-made view model.
    init(previewViewModel: SavedPlacesViewModel) {
        _viewModel = State(wrappedValue: previewViewModel)
    }
}

#Preview("Data") {
    NavigationStack {
        SavedPlacesScreen(previewViewModel: SavedPlacesViewModel())
    }
}

#Preview("Empty") {
    NavigationStack {
        SavedPlacesScreen(previewViewModel: SavedPlacesViewModel(isEmptyView: true))
    }
}

#Preview("Label alert") {
    NavigationStack {
        SavedPlacesScreen(previewViewModel: SavedPlacesViewModel(isLabeling: true))
    }
}

#Preview("Long text") {
    NavigationStack {
        SavedPlacesScreen(previewViewModel: SavedPlacesViewModel(store: .mock(places: [.mockLongText(), .mock()])))
    }
}

#endif
