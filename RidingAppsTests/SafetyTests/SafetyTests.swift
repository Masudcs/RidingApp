import Testing
@testable import RidingApps

@Suite("MockSafetyRepository")
struct SafetyTests {
    @Test("triggerSOS returns a dispatcher-notified alert")
    func triggerSOSNotifiesDispatcher() async throws {
        let service = MockSafetyRepository()
        let location = GeoPoint(latitude: 23.8103, longitude: 90.4125)

        let alert = try await service.triggerSOS(tripId: "trip-1", role: .rider, location: location)

        #expect(alert.status == .dispatcherNotified)
        #expect(alert.tripId == "trip-1")
        #expect(alert.triggeredBy == .rider)
    }

    @Test("addEmergencyContact and fetchEmergencyContacts round-trip")
    func addAndFetchContactsRoundTrip() async throws {
        let service = MockSafetyRepository()
        let initialCount = try await service.fetchEmergencyContacts().count

        let newContact = EmergencyContact(name: "Test Contact", phoneNumber: "+8801812345678")
        try await service.addEmergencyContact(newContact)

        let contacts = try await service.fetchEmergencyContacts()
        #expect(contacts.count == initialCount + 1)
        #expect(contacts.contains(where: { $0.id == newContact.id }))
    }

    @Test("removeEmergencyContact removes the contact")
    func removeContact() async throws {
        let service = MockSafetyRepository()
        let newContact = EmergencyContact(name: "Removable", phoneNumber: "+8801900000000")
        try await service.addEmergencyContact(newContact)

        try await service.removeEmergencyContact(id: newContact.id)

        let contacts = try await service.fetchEmergencyContacts()
        #expect(!contacts.contains(where: { $0.id == newContact.id }))
    }

    @Test("SilentSOSListener codeword matching is substring-based and case/whitespace insensitive")
    func silentSOSCodewordMatching() {
        #expect(SilentSOSListener.matches(transcription: "...please help me now...", codeword: "help me now"))
        #expect(SilentSOSListener.matches(transcription: "  Help Me NOW right away", codeword: "help me now"))
        #expect(!SilentSOSListener.matches(transcription: "help me later", codeword: "help me now"))
    }
}

@Suite("TripRecordingRepository")
struct TripRecordingServiceTests {
    @Test("recordings(for:) starts empty for an unknown trip id")
    func recordingsStartEmpty() async throws {
        let service = TripRecordingRepository()
        let recordings = try await service.recordings(for: "unknown-trip-id")
        #expect(recordings.isEmpty)
    }

    @Test("stopRecording without a prior startRecording throws noActiveRecording")
    func stopWithoutStartThrows() async throws {
        let service = TripRecordingRepository()
        await #expect(throws: TripRecordingError.self) {
            _ = try await service.stopRecording()
        }
    }
}

// A TripRecordingKeyStore round-trip test (generate/store/read-back) was tried here but is not
// included: the bare SPM test bundle has no code-signing team/entitlements, so SecItemAdd fails
// with errSecMissingEntitlement (-34018) purely as an artifact of the unsigned test host, not a
// defect in the wrapper - the app target (which has real signing/entitlements) does not hit this.

@Suite("String.pathEscaped")
struct PathEscapedTests {
    @Test("leaves plain ids unchanged")
    func plainIdsAreUnchanged() {
        #expect("trip-123_A.b~".pathEscaped == "trip-123_A.b~")
    }

    @Test("escapes characters that would change the path")
    func reservedCharactersAreEscaped() {
        #expect("a/b".pathEscaped == "a%2Fb")
        #expect("a?b#c".pathEscaped == "a%3Fb%23c")
        #expect("100%".pathEscaped == "100%25")
        #expect("a b".pathEscaped == "a%20b")
        #expect("../x".pathEscaped == "..%2Fx")
    }
}
