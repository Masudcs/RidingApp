import SwiftUI

/// Start/stop trip audio recording and list the recordings made for this trip.
public struct TripRecordingScreen: View {
    @State private var viewModel: TripRecordingViewModel

    public init(tripId: String, viewModel: TripRecordingViewModel? = nil) {
        _viewModel = State(wrappedValue: viewModel ?? TripRecordingViewModel(tripId: tripId))
    }

    public var body: some View {
        List {
            if let errorMessage = viewModel.errorMessage {
                Section {
                    ErrorBanner(errorMessage)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            Section {
                Text("Recordings are encrypted on your device and only used for dispute resolution.")
                    .font(BrandTypography.caption)
                    .foregroundStyle(BrandColor.textSecondary)

                if viewModel.isRecording {
                    SecondaryButton("Stop Recording", systemImage: "stop.circle.fill") {
                        viewModel.didTapToggleRecording()
                    }
                } else {
                    PrimaryButton(
                        "Start Recording",
                        systemImage: "mic.circle.fill",
                        isLoading: viewModel.isBusy
                    ) {
                        viewModel.didTapToggleRecording()
                    }
                }
            }
            .listRowInsets(EdgeInsets())
            .padding(16)
            .listRowBackground(Color.clear)

            Section("Past Recordings") {
                if viewModel.recordings.isEmpty {
                    Text("No recordings for this trip yet.")
                        .font(BrandTypography.caption)
                        .foregroundStyle(BrandColor.textSecondary)
                } else {
                    ForEach(viewModel.recordings) { recording in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.title(for: recording))
                                .font(BrandTypography.headline)
                            Text(viewModel.subtitle(for: recording))
                                .font(BrandTypography.caption)
                                .foregroundStyle(BrandColor.textSecondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Trip Recording")
        .onAppear {
            viewModel.onAppear()
        }
    }
}

#if DEBUG

#Preview("Loading") {
    NavigationStack {
        TripRecordingScreen(tripId: "trip-1", viewModel: TripRecordingViewModel(isLoading: true))
    }
}

#Preview("Data") {
    NavigationStack {
        TripRecordingScreen(tripId: "trip-1", viewModel: TripRecordingViewModel())
    }
}

#Preview("Recording") {
    NavigationStack {
        TripRecordingScreen(tripId: "trip-1", viewModel: TripRecordingViewModel(isRecording: true))
    }
}

#Preview("Empty") {
    NavigationStack {
        TripRecordingScreen(tripId: "trip-1", viewModel: TripRecordingViewModel(isEmptyView: true))
    }
}

#Preview("Error") {
    NavigationStack {
        TripRecordingScreen(tripId: "trip-1", viewModel: TripRecordingViewModel(isError: true))
    }
}

#Preview("Data - Dark") {
    NavigationStack {
        TripRecordingScreen(tripId: "trip-1", viewModel: TripRecordingViewModel())
    }
    .preferredColorScheme(.dark)
}

#endif
