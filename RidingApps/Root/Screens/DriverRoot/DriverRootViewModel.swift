import SwiftUI

/// Holds the signed-in driver and their verification record for `DriverRootScreen`, and owns the
/// driver's `ReferralStore` so it survives tab switches.
///
/// A new driver starts as `.pending`. While pending, this view model asks the backend for the
/// review result (`pollUntilDecided`, or the "Check status" button) and, when it changes, reports
/// it through `onVerificationUpdated` so `RootViewModel` can save it.
@MainActor
@Observable
final class DriverRootViewModel {
    let driver: AppUser
    /// Latest known review record. Updated by `refreshVerification`.
    private(set) var verification: DriverVerification?
    let referralStore: ReferralStore
    /// True while a status check is running (drives the button spinner).
    private(set) var isRefreshing = false
    /// Shown under the button when the last status check failed.
    private(set) var refreshError: String?

    /// True while the rejected driver is filling in the documents form again.
    private(set) var isResubmitting = false

    @ObservationIgnored private let repository: IAuthRepository
    @ObservationIgnored private let onVerificationUpdated: (DriverVerification) -> Void
    @ObservationIgnored private let logger = AppLogger(category: "DriverRoot")

    /// How long to wait between automatic status checks while the review is pending.
    @ObservationIgnored private let pollInterval: Duration = .seconds(15)
    /// Set only by the debug preview initializer; stops status checks and polling.
    @ObservationIgnored private var isPreview = false

    init(
        driver: AppUser,
        verification: DriverVerification?,
        repository: IAuthRepository = AuthRepositoryFactory.make(),
        onVerificationUpdated: @escaping (DriverVerification) -> Void = { _ in }
    ) {
        self.driver = driver
        self.verification = verification
        self.repository = repository
        self.onVerificationUpdated = onVerificationUpdated
        referralStore = ReferralStore(userId: driver.id)
    }

    /// Gate for the driver tabs: only `.verified` drivers may go online; others see the review screen.
    var isVerified: Bool {
        verification?.status == .verified
    }

    /// True while the backend may still approve the driver, so checking again is worthwhile.
    var isAwaitingReview: Bool {
        verification?.status == .pending
    }

    /// True when the driver was rejected and may send new documents.
    var canResubmit: Bool {
        verification?.status == .rejected
    }

    /// Opens the documents form again (only offered after a rejection).
    func beginResubmit() {
        guard canResubmit else { return }
        isResubmitting = true
    }

    /// Closes the documents form without submitting.
    func cancelResubmit() {
        isResubmitting = false
    }

    /// The new documents were submitted: store the (pending) record, tell the caller, and close the
    /// form. The screen restarts polling because the status changed.
    func didResubmit(_ newVerification: DriverVerification) {
        guard isResubmitting else { return }
        verification = newVerification
        isResubmitting = false
        refreshError = nil
        onVerificationUpdated(newVerification)
    }

    /// Asks the backend for the current review status once. Ignored if a check is already running.
    /// Failures keep the old status and set `refreshError`; the driver can try again.
    func refreshVerification() async {
        guard !isPreview else { return }
        guard !isRefreshing, let current = verification else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let latest = try await repository.fetchDriverVerification(for: driver.id, current: current)
            refreshError = nil
            guard latest != current else { return }
            verification = latest
            onVerificationUpdated(latest)
        } catch is CancellationError {
            // The screen went away; not an error.
        } catch {
            logger.error("Driver verification refresh failed: \(error.localizedDescription)")
            refreshError = String(localized: "Couldn't check your status. Please try again.")
        }
    }

    /// Checks every `pollInterval` until the review is decided or the calling task is cancelled
    /// (run it from `.task`, which cancels automatically when the screen disappears).
    func pollUntilDecided() async {
        guard !isPreview else { return }
        while isAwaitingReview, !Task.isCancelled {
            await refreshVerification()
            try? await Task.sleep(for: pollInterval)
        }
    }
}

#if DEBUG

extension DriverRootViewModel {
    /// Fixed fake driver in the given review state. `isLoading` is a status check in flight,
    /// `isError` the failed-check banner, `isResubmitting` the documents form.
    /// `isPreview` has no default to keep init calls explicit.
    convenience init(
        isPreview: Bool,
        status: DriverVerification.Status = .verified,
        isLoading: Bool = false,
        isError: Bool = false,
        isResubmitting: Bool = false
    ) {
        self.init(
            driver: .mockDriver(id: "preview-user"),
            verification: .mock(status: status),
            repository: MockAuthRepository()
        )
        self.isPreview = isPreview
        self.isRefreshing = isLoading
        self.refreshError = isError ? String(localized: "Couldn't check your status. Please try again.") : nil
        self.isResubmitting = isResubmitting
    }
}

#endif
