import Testing
import Foundation
@testable import RidingApps

struct AuthTests {
    private static let phone = "+8801700000000"

    private func makeVerification(status: DriverVerification.Status = .notSubmitted) -> DriverVerification {
        DriverVerification(
            nidNumber: "123456789",
            drivingLicenseNumber: "DL-001",
            status: status,
            vehicleType: .car,
            vehicleRegistrationPlate: "DHA-1234"
        )
    }

    // MARK: MockAuthRepository

    @Test func verifyOTPRejectsZeroCode() async {
        let repository = MockAuthRepository()
        await #expect(throws: AuthError.invalidCode) {
            _ = try await repository.verifyOTP(phoneNumber: Self.phone, code: "0000", role: .rider)
        }
    }

    @Test func verifyOTPRejectsMalformedCodes() async {
        let repository = MockAuthRepository()
        for code in ["123", "1234567", "12a4", ""] {
            await #expect(throws: AuthError.invalidCode) {
                _ = try await repository.verifyOTP(phoneNumber: Self.phone, code: code, role: .rider)
            }
        }
    }

    @Test func verifyOTPAcceptsValidCode() async throws {
        let repository = MockAuthRepository()
        let session = try await repository.verifyOTP(phoneNumber: Self.phone, code: "1234", role: .driver)
        #expect(session.user.phoneNumber == Self.phone)
        #expect(session.user.role == .driver)
        #expect(!session.tokens.accessToken.isEmpty)
        #expect(!session.tokens.refreshToken.isEmpty)
        #expect(!session.tokens.isExpired)
        // About 15 minutes of validity.
        let lifetime = session.tokens.expiresAt.timeIntervalSinceNow
        #expect(lifetime > 14 * 60 && lifetime <= 15 * 60)
    }

    @Test func submitDriverVerificationReturnsPendingStatus() async throws {
        let repository = MockAuthRepository()
        let result = try await repository.submitDriverVerification(makeVerification(), for: "user-1")
        #expect(result.status == .pending)
    }

    @Test func fetchDriverVerificationApprovesPendingOnly() async throws {
        let repository = MockAuthRepository()
        let approved = try await repository.fetchDriverVerification(for: "u", current: makeVerification(status: .pending))
        #expect(approved.status == .verified)
        #expect(approved.lastRecheckedAt != nil)

        let rejected = makeVerification(status: .rejected)
        let unchanged = try await repository.fetchDriverVerification(for: "u", current: rejected)
        #expect(unchanged == rejected)
    }

    // MARK: PhoneEntryViewModel

    @MainActor @Test func phoneNormalizationStripsFormatting() {
        #expect(PhoneEntryViewModel.normalized("+880 1700-000000") == "+8801700000000")
        #expect(PhoneEntryViewModel.normalized("(017) 00 000 000") == "017 00 000 000".filter { $0.isNumber })
        #expect(PhoneEntryViewModel.normalized("abc") == "")
    }

    @MainActor @Test func phoneValidationEnforcesE164Lengths() {
        #expect(PhoneEntryViewModel.isValid("+8801700000000"))
        #expect(PhoneEntryViewModel.isValid("01700000"))
        #expect(PhoneEntryViewModel.isValid("1234567"))
        #expect(PhoneEntryViewModel.isValid("+123456789012345"))
        #expect(!PhoneEntryViewModel.isValid("123456"))
        #expect(!PhoneEntryViewModel.isValid("+1234567890123456"))
        #expect(!PhoneEntryViewModel.isValid("+"))
        #expect(!PhoneEntryViewModel.isValid(""))
        #expect(!PhoneEntryViewModel.isValid("12345+6789"))
    }

    @MainActor
    @Test func invalidPhoneShowsErrorAndDoesNotSendCode() {
        var sent: String?
        let viewModel = PhoneEntryViewModel(repository: MockAuthRepository()) { sent = $0 }
        viewModel.phoneNumber = "12"
        viewModel.didTapSendCode()
        #expect(viewModel.errorMessage != nil)
        #expect(!viewModel.isLoading)
        #expect(sent == nil)
    }

    @MainActor
    @Test func validPhoneReportsNormalizedNumber() async throws {
        var sent: String?
        let viewModel = PhoneEntryViewModel(repository: MockAuthRepository()) { sent = $0 }
        viewModel.phoneNumber = "+880 1700-000000"
        viewModel.didTapSendCode()
        #expect(viewModel.isLoading)
        try await waitUntil { sent != nil }
        #expect(sent == Self.phone)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: AuthSession flow

    @MainActor
    @Test func otpViewModelHandsAuthSessionToOnVerified() async throws {
        var received: AuthSession?
        let viewModel = OTPEntryViewModel(phoneNumber: Self.phone, repository: MockAuthRepository()) { received = $0 }
        viewModel.otpCode = "1234"
        viewModel.didTapVerify()
        try await waitUntil { received != nil }
        let session = try #require(received)
        #expect(session.user.phoneNumber == Self.phone)
        #expect(!session.tokens.accessToken.isEmpty)
    }

    @MainActor
    @Test func tokensFromCodeCheckReachOnAuthenticated() throws {
        var capturedTokens: SessionTokens?
        let flow = AuthFlowViewModel { _, _, tokens in capturedTokens = tokens }
        let tokens = SessionTokens(accessToken: "acc", refreshToken: "ref", expiresAt: .now.addingTimeInterval(900))

        flow.didSendCode(to: Self.phone)
        flow.didVerifyCode(user: AppUser(fullName: "New User", phoneNumber: Self.phone, role: .rider), tokens: tokens)
        flow.didSelectRole(.rider)
        flow.didCompleteProfile(gender: .male, womenSafeModeEnabled: false)

        #expect(capturedTokens == tokens)
    }

    @MainActor
    @Test func expiredSessionLogsTheUserOut() {
        let suite = "test.expired.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let sessionStore = SessionStore(service: "test.expired.\(UUID().uuidString)", defaults: defaults)
        defer { sessionStore.clear(); defaults.removePersistentDomain(forName: suite) }
        let viewModel = RootViewModel(sessionStore: sessionStore, authRepository: MockAuthRepository(), defaults: defaults)
        let tokens = SessionTokens(accessToken: "a", refreshToken: "r", expiresAt: .now.addingTimeInterval(900))
        viewModel.didAuthenticate(user: AppUser(fullName: "Tania", phoneNumber: Self.phone, role: .rider), verification: nil, tokens: tokens)
        #expect(viewModel.currentUser != nil)

        viewModel.onSessionExpired()

        #expect(viewModel.currentUser == nil)
    }

    // MARK: AuthFlowViewModel

    @MainActor
    @Test func riderFlowFinishesAfterProfileDetails() throws {
        var capturedUser: AppUser?
        var capturedVerification: DriverVerification?
        var callCount = 0
        let flow = AuthFlowViewModel { user, verification, _ in
            capturedUser = user
            capturedVerification = verification
            callCount += 1
        }
        #expect(flow.step == .phoneEntry)

        flow.didSendCode(to: Self.phone)
        #expect(flow.step == .otpEntry)
        #expect(flow.phoneNumber == Self.phone)

        flow.didVerifyCode(user: AppUser(fullName: "New User", phoneNumber: Self.phone, role: .rider))
        #expect(flow.step == .roleSelection)

        flow.didSelectRole(.rider)
        #expect(flow.step == .profileDetails)

        flow.didCompleteProfile(gender: .female, womenSafeModeEnabled: true)
        #expect(flow.step == .done)
        #expect(callCount == 1)
        let user = try #require(capturedUser)
        #expect(user.gender == .female)
        #expect(user.womenSafeModeEnabled == true)
        #expect(capturedVerification == nil)

        // A double tap must not finish the flow twice.
        flow.didCompleteProfile(gender: .female, womenSafeModeEnabled: true)
        #expect(callCount == 1)
    }

    @MainActor
    @Test func driverFlowForcesWomenSafeModeOffAndNeedsOnboarding() throws {
        var capturedUser: AppUser?
        var capturedVerification: DriverVerification?
        var callCount = 0
        let flow = AuthFlowViewModel { user, verification, _ in
            capturedUser = user
            capturedVerification = verification
            callCount += 1
        }
        flow.didSendCode(to: Self.phone)
        flow.didVerifyCode(user: AppUser(fullName: "New User", phoneNumber: Self.phone, role: .driver))
        flow.didSelectRole(.driver)
        #expect(flow.step == .profileDetails)

        flow.didCompleteProfile(gender: .male, womenSafeModeEnabled: true)
        #expect(flow.step == .driverOnboarding)
        #expect(callCount == 0)
        #expect(flow.currentUser?.womenSafeModeEnabled == false)

        let verification = makeVerification(status: .pending)
        flow.didSubmitDriverVerification(verification)
        #expect(flow.step == .done)
        #expect(callCount == 1)
        #expect(capturedUser?.role == .driver)
        #expect(capturedVerification == verification)

        flow.didSubmitDriverVerification(verification)
        #expect(callCount == 1)
    }

    @MainActor
    @Test func completingProfileOutOfOrderIsIgnored() {
        var callCount = 0
        let flow = AuthFlowViewModel { _, _, _ in callCount += 1 }
        flow.didCompleteProfile(gender: .male, womenSafeModeEnabled: false)
        flow.didSubmitDriverVerification(makeVerification())
        #expect(flow.step == .phoneEntry)
        #expect(callCount == 0)
    }

    // MARK: DriverRootViewModel

    @MainActor
    @Test func refreshVerificationApprovesPendingDriverAndNotifies() async {
        let driver = AppUser(fullName: "Karim", phoneNumber: Self.phone, role: .driver)
        var updated: DriverVerification?
        let viewModel = DriverRootViewModel(
            driver: driver,
            verification: makeVerification(status: .pending),
            repository: MockAuthRepository()
        ) { updated = $0 }
        #expect(viewModel.isAwaitingReview)
        #expect(!viewModel.isVerified)

        await viewModel.refreshVerification()

        #expect(viewModel.isVerified)
        #expect(!viewModel.isAwaitingReview)
        #expect(updated?.status == .verified)
        #expect(viewModel.refreshError == nil)
        #expect(!viewModel.isRefreshing)
    }

    @MainActor
    @Test func refreshVerificationDoesNotNotifyWhenNothingChanged() async {
        let driver = AppUser(fullName: "Karim", phoneNumber: Self.phone, role: .driver)
        var notified = false
        let viewModel = DriverRootViewModel(
            driver: driver,
            verification: makeVerification(status: .rejected),
            repository: MockAuthRepository()
        ) { _ in notified = true }

        await viewModel.refreshVerification()

        #expect(viewModel.verification?.status == .rejected)
        #expect(!notified)
    }

    @MainActor
    @Test func refreshVerificationWithoutRecordIsNoOp() async {
        let driver = AppUser(fullName: "Karim", phoneNumber: Self.phone, role: .driver)
        let viewModel = DriverRootViewModel(driver: driver, verification: nil, repository: MockAuthRepository())
        await viewModel.refreshVerification()
        #expect(viewModel.verification == nil)
        #expect(!viewModel.isVerified)
    }

    // MARK: Back navigation

    @MainActor
    @Test func backNavigationWalksStepsAndKeepsValues() {
        let flow = AuthFlowViewModel { _, _, _ in }
        #expect(!flow.canGoBack)
        flow.didTapBack()
        #expect(flow.step == .phoneEntry)

        flow.didSendCode(to: Self.phone)
        #expect(flow.canGoBack)
        flow.didTapBack()
        #expect(flow.step == .phoneEntry)
        #expect(flow.phoneNumber == Self.phone)

        flow.didSendCode(to: Self.phone)
        flow.didVerifyCode(user: AppUser(fullName: "New User", phoneNumber: Self.phone, role: .driver))
        #expect(!flow.canGoBack)
        flow.didSelectRole(.driver)
        flow.didCompleteProfile(gender: .female, womenSafeModeEnabled: false)
        #expect(flow.step == .driverOnboarding)

        flow.didTapBack()
        #expect(flow.step == .profileDetails)
        #expect(flow.profileGender == .female)
        flow.didTapBack()
        #expect(flow.step == .roleSelection)
        #expect(flow.currentUser != nil)
    }

    @MainActor
    @Test func backIsNotAvailableAfterFlowIsDone() {
        var callCount = 0
        let flow = AuthFlowViewModel { _, _, _ in callCount += 1 }
        flow.didSendCode(to: Self.phone)
        flow.didVerifyCode(user: AppUser(fullName: "New User", phoneNumber: Self.phone, role: .rider))
        flow.didSelectRole(.rider)
        flow.didCompleteProfile(gender: .male, womenSafeModeEnabled: false)
        #expect(flow.step == .done)
        #expect(!flow.canGoBack)
        flow.didTapBack()
        #expect(flow.step == .done)
        #expect(callCount == 1)
    }

    @MainActor
    @Test func lateOTPResultAfterGoingBackIsIgnored() {
        let flow = AuthFlowViewModel { _, _, _ in }
        flow.didSendCode(to: Self.phone)
        flow.didTapBack()
        flow.didVerifyCode(user: AppUser(fullName: "New User", phoneNumber: Self.phone, role: .rider))
        #expect(flow.step == .phoneEntry)
        #expect(flow.currentUser == nil)
    }

    @MainActor
    @Test func phoneEntryIsPrefilled() {
        let viewModel = PhoneEntryViewModel(initialPhoneNumber: Self.phone, repository: MockAuthRepository()) { _ in }
        #expect(viewModel.phoneNumber == Self.phone)
    }

    // MARK: Resend code

    @MainActor
    private func makeOTPViewModel(repository: IAuthRepository = MockAuthRepository()) -> OTPEntryViewModel {
        OTPEntryViewModel(
            phoneNumber: Self.phone,
            repository: repository,
            resendCooldownSeconds: 2,
            tickInterval: .milliseconds(10)
        ) { _ in }
    }

    @MainActor
    @Test func resendIsBlockedDuringCooldownThenWorks() async throws {
        let repository = CountingAuthRepository()
        let viewModel = makeOTPViewModel(repository: repository)
        viewModel.otpCode = "123"
        #expect(!viewModel.canResend)
        viewModel.didTapResend()
        #expect(!viewModel.isResending)
        #expect(viewModel.otpCode == "123")
        #expect(repository.requestCount == 0)

        viewModel.startCooldownIfNeeded()
        try await waitUntil { viewModel.canResend }
        #expect(viewModel.resendSecondsRemaining == 0)

        viewModel.didTapResend()
        // Double tap while the request runs must not send a second code.
        viewModel.didTapResend()
        #expect(viewModel.isResending)
        #expect(viewModel.otpCode.isEmpty)
        try await waitUntil { !viewModel.isResending }
        #expect(repository.requestCount == 1)
        #expect(viewModel.resendMessage != nil)
        #expect(!viewModel.resendFailed)
        // The cooldown starts again after a resend.
        #expect(viewModel.resendSecondsRemaining > 0)
        viewModel.cancelTasks()
    }

    @MainActor
    @Test func resendFailureShowsMessageAndRestartsCooldown() async throws {
        let repository = CountingAuthRepository(fails: true)
        let viewModel = makeOTPViewModel(repository: repository)
        viewModel.startCooldownIfNeeded()
        try await waitUntil { viewModel.canResend }
        viewModel.didTapResend()
        try await waitUntil { !viewModel.isResending }
        #expect(viewModel.resendFailed)
        #expect(viewModel.resendMessage != nil)
        #expect(!viewModel.canResend)
        viewModel.cancelTasks()
    }

    @MainActor
    @Test func cancelStopsCountdown() async throws {
        let viewModel = makeOTPViewModel()
        viewModel.startCooldownIfNeeded()
        viewModel.cancelTasks()
        let remaining = viewModel.resendSecondsRemaining
        try await Task.sleep(for: .milliseconds(80))
        #expect(viewModel.resendSecondsRemaining == remaining)
    }

    // MARK: Driver resubmit

    @MainActor
    @Test func resubmitAfterRejectionBecomesPendingAndNotifies() {
        let driver = AppUser(fullName: "Karim", phoneNumber: Self.phone, role: .driver)
        var updated: DriverVerification?
        let viewModel = DriverRootViewModel(
            driver: driver,
            verification: makeVerification(status: .rejected),
            repository: MockAuthRepository()
        ) { updated = $0 }
        #expect(viewModel.canResubmit)
        viewModel.beginResubmit()
        #expect(viewModel.isResubmitting)

        viewModel.didResubmit(makeVerification(status: .pending))
        #expect(!viewModel.isResubmitting)
        #expect(viewModel.verification?.status == .pending)
        #expect(viewModel.isAwaitingReview)
        #expect(updated?.status == .pending)
    }

    @MainActor
    @Test func resubmitIsOnlyOfferedWhenRejected() {
        let driver = AppUser(fullName: "Karim", phoneNumber: Self.phone, role: .driver)
        var notified = false
        let viewModel = DriverRootViewModel(
            driver: driver,
            verification: makeVerification(status: .pending),
            repository: MockAuthRepository()
        ) { _ in notified = true }
        #expect(!viewModel.canResubmit)
        viewModel.beginResubmit()
        #expect(!viewModel.isResubmitting)
        viewModel.didResubmit(makeVerification(status: .pending))
        #expect(!notified)
    }

    @MainActor
    @Test func cancelResubmitKeepsRejectedStatus() {
        let driver = AppUser(fullName: "Karim", phoneNumber: Self.phone, role: .driver)
        let viewModel = DriverRootViewModel(driver: driver, verification: makeVerification(status: .rejected), repository: MockAuthRepository())
        viewModel.beginResubmit()
        viewModel.cancelResubmit()
        #expect(!viewModel.isResubmitting)
        #expect(viewModel.verification?.status == .rejected)
    }

    @MainActor
    @Test func onboardingPrefillsFromPreviousVerification() {
        let viewModel = DriverOnboardingViewModel(
            userId: "u",
            initialVerification: makeVerification(status: .rejected),
            repository: MockAuthRepository()
        ) { _ in }
        #expect(viewModel.nidNumber == "123456789")
        #expect(viewModel.vehicleType == .car)
        #expect(viewModel.vehicleRegistrationPlate == "DHA-1234")
    }
}

/// Test double that counts `requestOTP` calls and can be told to fail.
final class CountingAuthRepository: IAuthRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private let fails: Bool

    init(fails: Bool = false) { self.fails = fails }

    var requestCount: Int { lock.withLock { count } }

    func requestOTP(phoneNumber: String) async throws {
        lock.withLock { count += 1 }
        try await Task.sleep(for: .milliseconds(30))
        if fails { throw AuthError.invalidCode }
    }
    func verifyOTP(phoneNumber: String, code: String, role: UserRole) async throws -> AuthSession {
        AuthSession(user: AppUser(fullName: "New User", phoneNumber: phoneNumber, role: role), tokens: SessionTokens(accessToken: "a", refreshToken: "r", expiresAt: Date().addingTimeInterval(900)))
    }
    func submitDriverVerification(_ verification: DriverVerification, for userId: String) async throws -> DriverVerification { verification }
    func fetchDriverVerification(for userId: String, current: DriverVerification) async throws -> DriverVerification { current }
    func deleteAccount(userId: String) async throws {}
}

@MainActor
func waitUntil(
    timeout: Duration = .seconds(5),
    _ condition: @MainActor () -> Bool
) async throws {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while !condition() {
        if ContinuousClock.now > deadline {
            Issue.record("Timed out waiting for condition")
            return
        }
        try await Task.sleep(for: .milliseconds(20))
    }
}

// MARK: Account deletion

/// Auth backend stub whose `deleteAccount` either succeeds or throws.
private struct StubDeleteAuthRepository: IAuthRepository {
    let failsToDelete: Bool

    func requestOTP(phoneNumber: String) async throws {}
    func verifyOTP(phoneNumber: String, code: String, role: UserRole) async throws -> AuthSession {
        AuthSession(user: AppUser(fullName: "Stub", phoneNumber: phoneNumber, role: role), tokens: SessionTokens(accessToken: "a", refreshToken: "r", expiresAt: Date().addingTimeInterval(900)))
    }
    func submitDriverVerification(_ verification: DriverVerification, for userId: String) async throws -> DriverVerification { verification }
    func fetchDriverVerification(for userId: String, current: DriverVerification) async throws -> DriverVerification { current }
    func deleteAccount(userId: String) async throws {
        if failsToDelete { throw NetworkError.server(statusCode: 500) }
    }
}

@MainActor
struct AccountDeletionTests {
    private func makeViewModel(failsToDelete: Bool) -> (RootViewModel, UserDefaults, cleanup: () -> Void) {
        let suite = "test.delete.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let sessionStore = SessionStore(service: "test.delete.\(UUID().uuidString)", defaults: defaults)
        let viewModel = RootViewModel(
            sessionStore: sessionStore,
            authRepository: StubDeleteAuthRepository(failsToDelete: failsToDelete),
            defaults: defaults
        )
        return (viewModel, defaults, { sessionStore.clear(); defaults.removePersistentDomain(forName: suite) })
    }

    @Test func deletingAccountSignsOutAndClearsThatUsersLocalData() async {
        let (viewModel, defaults, cleanup) = makeViewModel(failsToDelete: false)
        defer { cleanup() }
        let user = AppUser(fullName: "Tania", phoneNumber: "+8801700000000", role: .rider)
        viewModel.didAuthenticate(user: user, verification: nil)
        LocalStore.save(120, forKey: "loyalty.points.\(user.id)", defaults: defaults)
        LocalStore.save(50, forKey: "loyalty.points.other-user", defaults: defaults)

        let deleted = await viewModel.deleteAccount()

        #expect(deleted)
        #expect(viewModel.currentUser == nil)
        #expect(defaults.object(forKey: "loyalty.points.\(user.id)") == nil)
        #expect(defaults.object(forKey: "loyalty.points.other-user") != nil)
    }

    @Test func failedDeletionKeepsUserSignedInWithData() async {
        let (viewModel, defaults, cleanup) = makeViewModel(failsToDelete: true)
        defer { cleanup() }
        let user = AppUser(fullName: "Tania", phoneNumber: "+8801700000000", role: .rider)
        viewModel.didAuthenticate(user: user, verification: nil)
        LocalStore.save(120, forKey: "loyalty.points.\(user.id)", defaults: defaults)

        let deleted = await viewModel.deleteAccount()

        #expect(!deleted)
        #expect(viewModel.currentUser?.id == user.id)
        #expect(defaults.object(forKey: "loyalty.points.\(user.id)") != nil)
    }

    @Test func deletingWhenSignedOutDoesNothing() async {
        let (viewModel, _, cleanup) = makeViewModel(failsToDelete: false)
        defer { cleanup() }
        #expect(await viewModel.deleteAccount() == false)
    }
}
