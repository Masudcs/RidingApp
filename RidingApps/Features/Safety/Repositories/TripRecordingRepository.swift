import AVFoundation
import CryptoKit
import Foundation

/// Records trip audio with `AVAudioRecorder` into a temporary file, then encrypts it with
/// AES-GCM (key from `TripRecordingKeyStore`) and deletes the plaintext. Recordings are only
/// listed in memory; the `.enc` files stay in Documents.
public actor TripRecordingRepository: ITripRecordingRepository {
    private let keyStore: TripRecordingKeyStore
    private var recorder: AVAudioRecorder?
    private var activeTripId: String?
    private var activeTempFileURL: URL?
    private var recordingStartedAt: Date?
    private var recordingsByTripId: [String: [TripRecording]] = [:]

    public init(keyStore: TripRecordingKeyStore = TripRecordingKeyStore()) {
        self.keyStore = keyStore
    }

    public func startRecording(tripId: String) async throws {
        guard recorder == nil else { throw TripRecordingError.alreadyRecording }
        guard AVAudioSession.sharedInstance().recordPermission == .granted else {
            throw TripRecordingError.microphonePermissionDenied
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        let newRecorder: AVAudioRecorder
        do {
            newRecorder = try AVAudioRecorder(url: tempURL, settings: settings)
        } catch {
            try? session.setActive(false)
            throw error
        }
        // record() returns false if the hardware is busy (e.g. a phone call); don't pretend to record.
        guard newRecorder.record() else {
            try? session.setActive(false)
            throw TripRecordingError.audioSessionUnavailable
        }

        recorder = newRecorder
        activeTripId = tripId
        activeTempFileURL = tempURL
        recordingStartedAt = Date()
    }

    public func stopRecording() async throws -> TripRecording {
        guard let recorder, let tripId = activeTripId, let tempURL = activeTempFileURL, let startedAt = recordingStartedAt else {
            throw TripRecordingError.noActiveRecording
        }
        let duration = recorder.currentTime
        recorder.stop()
        try? AVAudioSession.sharedInstance().setActive(false)

        // Clear state first so a failure below can't leave us stuck on `alreadyRecording`.
        // The plaintext temp file is always removed, even if encryption fails.
        self.recorder = nil
        activeTripId = nil
        activeTempFileURL = nil
        recordingStartedAt = nil
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Read-then-delete rather than moving the file: AES.GCM needs the full plaintext in memory
        // anyway, and this keeps the on-disk plaintext window as short as possible.
        let plaintext = try Data(contentsOf: tempURL)
        let key = SymmetricKey(data: try keyStore.loadOrCreateKeyData())
        let sealedBox = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealedBox.combined else {
            throw TripRecordingError.audioSessionUnavailable
        }

        let encryptedURL = try encryptedFileDestination(tripId: tripId)
        try combined.write(to: encryptedURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])

        let recording = TripRecording(
            tripId: tripId,
            encryptedFileURL: encryptedURL,
            durationSeconds: duration,
            createdAt: startedAt
        )
        recordingsByTripId[tripId, default: []].append(recording)
        return recording
    }

    public func recordings(for tripId: String) async throws -> [TripRecording] {
        recordingsByTripId[tripId] ?? []
    }

    private func encryptedFileDestination(tripId: String) throws -> URL {
        let documents = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return documents.appendingPathComponent("\(tripId)-\(UUID().uuidString).enc")
    }
}
