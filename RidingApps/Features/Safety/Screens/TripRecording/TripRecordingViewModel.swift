import Observation
import AVFoundation
import Foundation

/// Start/stop control and list for the trip audio recordings. One button toggles; `isBusy` blocks
/// a second tap while the repository or the mic-permission prompt is working.
@MainActor
@Observable
public final class TripRecordingViewModel {
    /// True only after the repository confirmed recording started.
    public private(set) var isRecording: Bool = false
    public private(set) var isBusy: Bool = false
    public private(set) var recordings: [TripRecording] = []
    public private(set) var errorMessage: String?

    @ObservationIgnored private let repository: ITripRecordingRepository
    private let tripId: String
    /// Set only by the debug preview initializer; stops every method from touching the mic or repository.
    @ObservationIgnored private var isPreview = false

    public init(tripId: String, repository: ITripRecordingRepository = TripRecordingRepository()) {
        self.tripId = tripId
        self.repository = repository
    }

    public func title(for recording: TripRecording) -> String {
        recording.id
    }

    public func subtitle(for recording: TripRecording) -> String {
        "\(formattedDuration(recording.durationSeconds)) - \(formattedDate(recording.createdAt))"
    }

    /// Loads recordings already made for this trip.
    public func onAppear() {
        guard !isPreview else { return }
        Task {
            do {
                self.recordings = try await repository.recordings(for: tripId)
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    public func didTapToggleRecording() {
        guard !isPreview else { return }
        guard !isBusy else { return }
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        errorMessage = nil
        isBusy = true
        Task {
            let permissionGranted = await requestMicrophonePermission()
            guard permissionGranted else {
                self.errorMessage = String(localized: "Microphone access is required to record this trip.")
                self.isBusy = false
                return
            }
            do {
                try await repository.startRecording(tripId: tripId)
                self.isRecording = true
            } catch {
                self.errorMessage = error.localizedDescription
            }
            self.isBusy = false
        }
    }

    private func stopRecording() {
        errorMessage = nil
        isBusy = true
        Task {
            do {
                let recording = try await repository.stopRecording()
                self.recordings.append(recording)
                self.isRecording = false
            } catch {
                // The repository ends the recording even when saving fails, so don't leave the UI
                // showing "recording" with nothing running.
                self.isRecording = false
                self.errorMessage = error.localizedDescription
            }
            self.isBusy = false
        }
    }

    private func formattedDuration(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds.rounded())
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

#if DEBUG

extension TripRecordingViewModel {
    /// Fixed fake state. Loading is the busy "Start" button, empty has no recordings, error shows the banner.
    /// Nothing reaches the repository, microphone or audio session.
    convenience init(isPreview: Bool = true, isLoading: Bool = false, isError: Bool = false, isEmptyView: Bool = false, isRecording: Bool = false) {
        self.init(tripId: "trip-1")
        self.isPreview = isPreview
        self.isBusy = isLoading
        self.isRecording = isRecording
        self.recordings = isEmptyView || isLoading ? [] : TripRecording.mockList()
        self.errorMessage = isError ? String(localized: "Microphone access is required to record this trip.") : nil
    }
}

#endif
