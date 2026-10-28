import SwiftUI

/// Fare step: estimate + schedule toggle before a request, then the offer chat with the driver.
public struct FareNegotiationScreen: View {
    @State private var viewModel: FareNegotiationViewModel

    public init(
        rider: AppUser,
        draft: RideRequestDraft,
        scheduledRidesStore: ScheduledRidesStore,
        favoriteDriverIds: Set<String> = [],
        blockedDriverIds: Set<String> = [],
        repository: IBookingRepository = BookingRepository.makeDefault(),
        onTripMatched: @escaping (Trip) -> Void,
        onScheduledRideConfirmed: @escaping () -> Void,
        onCancelled: @escaping () -> Void
    ) {
        _viewModel = State(wrappedValue: FareNegotiationViewModel(
            rider: rider,
            draft: draft,
            scheduledRidesStore: scheduledRidesStore,
            favoriteDriverIds: favoriteDriverIds,
            blockedDriverIds: blockedDriverIds,
            repository: repository,
            onTripMatched: onTripMatched,
            onScheduledRideConfirmed: onScheduledRideConfirmed,
            onCancelled: onCancelled
        ))
    }

    public var body: some View {
        @Bindable var viewModel = viewModel
        VStack(spacing: 12) {
            FareSummaryCard(
                fareText: viewModel.suggestedFareText,
                insuranceText: viewModel.insuranceText,
                stopsText: viewModel.stopsText,
                surgeText: viewModel.isSurging ? viewModel.surgeButtonTitle : nil,
                onTapSurge: { viewModel.didTapSurgeInfo() }
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)

            if !viewModel.hasTrip {
                ScheduleCard(
                    scheduledFor: viewModel.scheduledFor,
                    onToggle: { viewModel.didToggleSchedule($0) },
                    onChangeDate: { viewModel.didChangeScheduledDate($0) }
                )
                .padding(.horizontal, 16)

                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(errorMessage)
                        .padding(.horizontal, 16)
                }

                Spacer()

                if viewModel.scheduledFor != nil {
                    PrimaryButton("Confirm Scheduled Ride") {
                        viewModel.didTapConfirmScheduledRide()
                    }
                    .padding(16)
                } else {
                    PrimaryButton("Request ride", isLoading: viewModel.isLoading) {
                        viewModel.didTapRequestRide()
                    }
                    .padding(16)
                }
            } else {
                FareNegotiationView(
                    offers: viewModel.offers,
                    notice: viewModel.womenSafeNotice,
                    errorMessage: viewModel.errorMessage,
                    acceptTitle: viewModel.acceptButtonTitle,
                    isLoading: viewModel.isLoading,
                    offerText: $viewModel.myOfferAmount,
                    canPropose: viewModel.canPropose,
                    onAccept: { viewModel.didTapAcceptOffer() },
                    onPropose: { viewModel.didTapPropose() }
                )

                SecondaryButton("Cancel ride", systemImage: "xmark.circle") {
                    viewModel.didTapCancelRide()
                }
                .padding(16)
            }
        }
        .background(BrandColor.background)
        .onAppear { viewModel.didAppear() }
        .sheet(isPresented: $viewModel.showSurgeSheet) {
            SurgeExplanationSheet(title: viewModel.surgeSheetTitle, reasons: viewModel.surgeReasons)
        }
        .sheet(isPresented: $viewModel.showCancellationSheet) {
            if let trip = viewModel.trip {
                CancellationScreen(trip: trip, onConfirm: { reason, fee in
                    viewModel.didConfirmCancellation(reason: reason, fee: fee)
                }, onKeepRide: {
                    viewModel.didKeepRide()
                })
            }
        }
    }
}

#if DEBUG

extension FareNegotiationScreen {
    /// Preview-only: shows a ready-made view model.
    init(previewViewModel: FareNegotiationViewModel) {
        _viewModel = State(wrappedValue: previewViewModel)
    }
}

#Preview("Estimate") {
    FareNegotiationScreen(previewViewModel: FareNegotiationViewModel())
}

#Preview("Loading estimate") {
    FareNegotiationScreen(previewViewModel: FareNegotiationViewModel(isLoading: true))
}

#Preview("Estimate error") {
    FareNegotiationScreen(previewViewModel: FareNegotiationViewModel(isError: true))
}

#Preview("Surge") {
    FareNegotiationScreen(previewViewModel: FareNegotiationViewModel(
        surge: SurgeContext(multiplier: 1.5, reasons: ["High demand in your area", "Rain in your area"])
    ))
}

#Preview("With stops") {
    FareNegotiationScreen(previewViewModel: FareNegotiationViewModel(withStops: true))
}

#Preview("Scheduled") {
    FareNegotiationScreen(previewViewModel: FareNegotiationViewModel(isScheduled: true))
}

#Preview("Driver countered") {
    FareNegotiationScreen(previewViewModel: FareNegotiationViewModel(trip: .mockNegotiating(lastOfferBy: .driver)))
}

#Preview("Waiting for driver") {
    FareNegotiationScreen(previewViewModel: FareNegotiationViewModel(trip: .mockNegotiating(lastOfferBy: .rider)))
}

#Preview("No offers yet") {
    FareNegotiationScreen(previewViewModel: FareNegotiationViewModel(isEmptyView: true))
}

#Preview("Offer error") {
    FareNegotiationScreen(previewViewModel: FareNegotiationViewModel(isError: true, trip: .mockNegotiating()))
}

#Preview("Women Safe matching") {
    FareNegotiationScreen(previewViewModel: FareNegotiationViewModel(trip: .mockNegotiating(womenSafeModeRequested: true)))
}

#Preview("Women Safe fallback driver") {
    FareNegotiationScreen(previewViewModel: FareNegotiationViewModel(trip: .mock(status: .driverAssigned, womenSafeModeRequested: true)))
}

#endif
