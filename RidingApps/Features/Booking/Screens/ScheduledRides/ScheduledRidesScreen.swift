import SwiftUI

/// Sheet listing rides the rider scheduled for later. "Start Now" books one immediately.
public struct ScheduledRidesScreen: View {
    @State private var viewModel: ScheduledRidesViewModel

    public init(
        store: ScheduledRidesStore,
        womenSafeModeEnabled: Bool = false,
        favoriteDriverIds: Set<String> = [],
        blockedDriverIds: Set<String> = [],
        repository: IBookingRepository = BookingRepository.makeDefault(),
        onStarted: @escaping (Trip) -> Void
    ) {
        _viewModel = State(wrappedValue: ScheduledRidesViewModel(
            store: store,
            womenSafeModeEnabled: womenSafeModeEnabled,
            favoriteDriverIds: favoriteDriverIds,
            blockedDriverIds: blockedDriverIds,
            repository: repository,
            onStarted: onStarted
        ))
    }

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.rides.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.system(size: 40))
                            .foregroundStyle(BrandColor.textSecondary)
                        Text("No scheduled rides yet")
                            .font(BrandTypography.body)
                            .foregroundStyle(BrandColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        List {
                            ForEach(viewModel.rides) { ride in
                                ScheduledRideRow(
                                    systemImageName: ride.vehicleType.systemImageName,
                                    routeText: viewModel.routeText(for: ride),
                                    fareText: ride.estimatedFare.formatted,
                                    dateText: viewModel.dateText(for: ride),
                                    isStarting: viewModel.isStarting
                                ) {
                                    viewModel.didTapStartNow(ride)
                                }
                            }
                            .onDelete { offsets in
                                viewModel.didDelete(at: offsets)
                            }
                        }
                        if let errorMessage = viewModel.errorMessage {
                            ErrorBanner(errorMessage)
                                .padding(16)
                        }
                    }
                }
            }
            .navigationTitle("Scheduled Rides")
        }
    }
}

#if DEBUG

extension ScheduledRidesScreen {
    /// Preview-only: shows a ready-made view model.
    init(previewViewModel: ScheduledRidesViewModel) {
        _viewModel = State(wrappedValue: previewViewModel)
    }
}

#Preview("Data") {
    ScheduledRidesScreen(previewViewModel: ScheduledRidesViewModel())
}

#Preview("Empty") {
    ScheduledRidesScreen(previewViewModel: ScheduledRidesViewModel(isEmptyView: true))
}

#Preview("Starting") {
    ScheduledRidesScreen(previewViewModel: ScheduledRidesViewModel(isLoading: true))
}

#Preview("Error") {
    ScheduledRidesScreen(previewViewModel: ScheduledRidesViewModel(isError: true))
}

#Preview("Long text") {
    ScheduledRidesScreen(previewViewModel: ScheduledRidesViewModel(rides: [.mockLongText()]))
}

#endif
