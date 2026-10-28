import Foundation

/// One finished, encrypted trip audio file. Only the encrypted copy is kept on device.
public struct TripRecording: Identifiable, Equatable, Sendable {
    public let id: String
    public let tripId: String
    public let encryptedFileURL: URL
    /// Length of the audio in seconds.
    public let durationSeconds: Double
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        tripId: String,
        encryptedFileURL: URL,
        durationSeconds: Double,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.tripId = tripId
        self.encryptedFileURL = encryptedFileURL
        self.durationSeconds = durationSeconds
        self.createdAt = createdAt
    }
}

/// Failures from `ITripRecordingRepository`.
public enum TripRecordingError: Error, Sendable {
    case microphonePermissionDenied
    case noActiveRecording
    case alreadyRecording
    /// The audio session could not record, or the encrypted data could not be produced.
    case audioSessionUnavailable
}

#if DEBUG

// Fixed fake data for SwiftUI previews. Debug builds only, so none of it ships.

public extension TripRecording {
    static func mock(id: String = "rec-1", tripId: String = "trip-1", durationSeconds: Double = 125) -> TripRecording {
        TripRecording(
            id: id,
            tripId: tripId,
            encryptedFileURL: URL(fileURLWithPath: "/tmp/\(id).enc"),
            durationSeconds: durationSeconds
        )
    }

    static func mockList(tripId: String = "trip-1") -> [TripRecording] {
        [
            .mock(id: "rec-1", tripId: tripId, durationSeconds: 125),
            .mock(id: "rec-2", tripId: tripId, durationSeconds: 48)
        ]
    }
}

#endif
