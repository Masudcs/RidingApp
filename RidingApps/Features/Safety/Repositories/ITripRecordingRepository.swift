import Foundation

/// Records trip audio, encrypts it on device and keeps track of the saved files.
public protocol ITripRecordingRepository: Sendable {
    /// Starts one recording. Throws `alreadyRecording` if one is active and
    /// `microphonePermissionDenied` if the mic permission has not been granted yet.
    func startRecording(tripId: String) async throws
    /// Stops the active recording and returns the encrypted file. Throws `noActiveRecording` if none.
    func stopRecording() async throws -> TripRecording
    /// Recordings made for this trip since the app launched (the list is not persisted).
    func recordings(for tripId: String) async throws -> [TripRecording]
}
