import AVFoundation
import Foundation
import Speech

/// Listens through the mic during an active trip and calls `triggerSOS` when the codeword is heard.
/// Speech recognition is forced on-device (`requiresOnDeviceRecognition`) so audio never leaves
/// the phone; if the device can't do that, it refuses to start instead of falling back to the server.
/// `TripTrackingViewModel` owns one and calls `start`/`stop` with the trip.
@MainActor
public final class SilentSOSListener: ObservableObject {
    /// True while the mic and recognizer are running.
    @Published public var isListening: Bool = false
    /// Set once the codeword was heard. Stays true even if sending the SOS failed (see `errorMessage`).
    @Published public var didTrigger: Bool = false
    /// Why listening could not start, or why the SOS request failed.
    @Published public var errorMessage: String?

    private let repository: ISafetyRepository
    private let codeword: String

    private let audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    /// Stops partial results of the same utterance from sending several SOS requests.
    private var hasTriggeredThisActivation = false
    /// True between `start` and the speech-permission callback, so a second `start` can't begin twice.
    private var isStarting = false

    public init(repository: ISafetyRepository = AppEnvironment.current.usesMockServices ? MockSafetyRepository.shared : SafetyRepository(), codeword: String = "help me now") {
        self.repository = repository
        self.codeword = codeword
    }

    /// Asks for speech permission if needed, then starts listening. Failures are reported through
    /// `errorMessage`. Does nothing if already listening or starting.
    /// Note: `location` is captured once, so the SOS carries the location from when listening began.
    public func start(tripId: String, role: UserRole, location: GeoPoint) {
        guard !isListening, !isStarting else { return }
        isStarting = true
        errorMessage = nil
        didTrigger = false
        hasTriggeredThisActivation = false

        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            Task { @MainActor in
                guard let self else { return }
                self.isStarting = false
                guard authStatus == .authorized else {
                    self.errorMessage = String(localized: "Speech recognition was not authorized.")
                    return
                }
                self.beginListening(tripId: tripId, role: role, location: location)
            }
        }
    }

    private func beginListening(tripId: String, role: UserRole, location: GeoPoint) {
        guard !isListening else { return }
        let recognizer = SFSpeechRecognizer()
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = String(localized: "Speech recognizer is unavailable.")
            return
        }
        guard recognizer.supportsOnDeviceRecognition else {
            errorMessage = String(localized: "On-device speech recognition isn't supported for this locale, so Silent SOS can't start (audio must never leave the device).")
            return
        }
        self.speechRecognizer = recognizer

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        self.recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            errorMessage = String(localized: "Could not start the audio engine: \(error.localizedDescription)")
            inputNode.removeTap(onBus: 0)
            recognitionRequest = nil
            return
        }

        isListening = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.handleTranscription(
                        result.bestTranscription.formattedString,
                        tripId: tripId,
                        role: role,
                        location: location
                    )
                }
                if error != nil || (result?.isFinal ?? false) {
                    self.stop()
                }
            }
        }
    }

    private func handleTranscription(_ transcription: String, tripId: String, role: UserRole, location: GeoPoint) {
        guard Self.matches(transcription: transcription, codeword: codeword) else { return }
        // Debounce: only fire once per activation even though partial results keep matching the same utterance.
        guard !hasTriggeredThisActivation else { return }
        hasTriggeredThisActivation = true
        didTrigger = true

        Task {
            do {
                _ = try await repository.triggerSOS(tripId: tripId, role: role, location: location)
            } catch {
                // The SOS did not go out, so allow the next match to try again.
                self.hasTriggeredThisActivation = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    /// Case-insensitive "contains" check, so the codeword can be part of a longer sentence.
    /// An empty codeword never matches.
    public nonisolated static func matches(transcription: String, codeword: String) -> Bool {
        let normalizedTranscription = transcription.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCodeword = codeword.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCodeword.isEmpty else { return false }
        return normalizedTranscription.contains(normalizedCodeword)
    }

    /// Stops the mic and recognizer. Safe to call when not listening.
    public func stop() {
        guard isListening else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
    }

    deinit {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
    }
}
