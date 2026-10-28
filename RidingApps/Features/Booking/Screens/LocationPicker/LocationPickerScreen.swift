import SwiftUI

/// Pickup / stops / dropoff lists. Stops and dropoff only appear once a pickup is chosen; tapping a
/// dropoff moves on to the fare step.
public struct LocationPickerScreen: View {
    @State private var viewModel: LocationPickerViewModel

    public init(
        vehicleType: VehicleType,
        savedPlaces: [SavedPlace] = [],
        repository: IBookingRepository = BookingRepository.makeDefault(),
        onContinue: @escaping (RideRequestDraft) -> Void
    ) {
        _viewModel = State(wrappedValue: LocationPickerViewModel(
            vehicleType: vehicleType,
            savedPlaces: savedPlaces,
            repository: repository,
            onContinue: onContinue
        ))
    }

    public var body: some View {
        @Bindable var viewModel = viewModel
        VStack(spacing: 0) {
            list

            if let errorMessage = viewModel.errorMessage {
                ErrorBanner(errorMessage)
                    .padding(16)
            }
        }
        .background(BrandColor.background)
        .onAppear { viewModel.didAppear() }
    }

    private var list: some View {
        List {
            Section("Pickup") {
                LocationSearchRow(title: "Search for an address") { viewModel.didTapSearchPickup() }
                if !viewModel.savedPlaces.isEmpty {
                    ForEach(viewModel.savedPlaces) { place in
                        SavedPlaceRow(
                            label: place.label,
                            title: place.location.title,
                            isSelected: place.location.id == viewModel.pickup?.id
                        ) {
                            viewModel.didSelectPickup(place.location)
                        }
                    }
                }
                ForEach(viewModel.pickupSuggestions) { location in
                    LocationRow(
                        title: location.title,
                        subtitle: location.subtitle,
                        isSelected: location.id == viewModel.pickup?.id
                    ) {
                        viewModel.didSelectPickup(location)
                    }
                }
            }

            if viewModel.pickup != nil {
                Section("Stops") {
                    ForEach(viewModel.stops) { stop in
                        HStack {
                            Text(stop.title)
                                .font(BrandTypography.body)
                            Spacer()
                            Button {
                                viewModel.didRemoveStop(stop)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(BrandColor.danger)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button {
                        viewModel.didTapAddStop()
                    } label: {
                        Label("Add a stop", systemImage: "plus.circle")
                    }
                    .disabled(!viewModel.canAddStop)
                }

                Section("Dropoff") {
                    LocationSearchRow(title: "Search for an address") { viewModel.didTapSearchDropoff() }
                    if !viewModel.savedPlaces.isEmpty {
                        ForEach(viewModel.savedPlaces) { place in
                            SavedPlaceRow(
                                label: place.label,
                                title: place.location.title,
                                isSelected: place.location.id == viewModel.dropoff?.id
                            ) {
                                viewModel.didSelectDropoff(place.location)
                            }
                        }
                    }
                    ForEach(viewModel.dropoffSuggestions) { location in
                        LocationRow(
                            title: location.title,
                            subtitle: location.subtitle,
                            isSelected: location.id == viewModel.dropoff?.id
                        ) {
                            viewModel.didSelectDropoff(location)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(isPresented: $viewModel.isPickingStop) {
            NavigationStack {
                List {
                    LocationSearchRow(title: "Search for an address") { viewModel.didTapSearchStop() }
                    ForEach(viewModel.stopCandidates) { location in
                        LocationRow(title: location.title, subtitle: location.subtitle, isSelected: false) {
                            viewModel.didPickStop(location)
                        }
                    }
                }
                .navigationTitle("Add a Stop")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { viewModel.isPickingStop = false }
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.isSearchingPickup) {
            AddressSearchScreen(title: "Search Pickup", onSelect: { location in
                viewModel.didFindPickup(location)
            }, onCancel: {
                viewModel.isSearchingPickup = false
            })
        }
        .sheet(isPresented: $viewModel.isSearchingDropoff) {
            AddressSearchScreen(title: "Search Dropoff", onSelect: { location in
                viewModel.didFindDropoff(location)
            }, onCancel: {
                viewModel.isSearchingDropoff = false
            })
        }
        .sheet(isPresented: $viewModel.isSearchingStop) {
            AddressSearchScreen(title: "Search Stop", onSelect: { location in
                viewModel.didFindStop(location)
            }, onCancel: {
                viewModel.isSearchingStop = false
            })
        }
    }
}

#if DEBUG

extension LocationPickerScreen {
    /// Preview-only: shows a ready-made view model.
    init(previewViewModel: LocationPickerViewModel) {
        _viewModel = State(wrappedValue: previewViewModel)
    }
}

#Preview("Pickup suggestions") {
    LocationPickerScreen(previewViewModel: LocationPickerViewModel())
}

#Preview("With saved places") {
    LocationPickerScreen(previewViewModel: LocationPickerViewModel(savedPlaces: SavedPlace.mockList()))
}

#Preview("Pickup chosen") {
    LocationPickerScreen(previewViewModel: LocationPickerViewModel(hasPickup: true, savedPlaces: SavedPlace.mockList()))
}

#Preview("With a stop") {
    LocationPickerScreen(previewViewModel: LocationPickerViewModel(hasPickup: true, hasStop: true))
}

#Preview("Error") {
    LocationPickerScreen(previewViewModel: LocationPickerViewModel(isError: true, hasPickup: true))
}

#Preview("Empty") {
    LocationPickerScreen(previewViewModel: LocationPickerViewModel(isEmptyView: true))
}

#endif
