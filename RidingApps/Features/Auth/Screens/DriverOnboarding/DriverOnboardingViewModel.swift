import Foundation
import Observation

/// Logic for the driver-only last step: collect ID and vehicle details and send them for review.
/// The result comes back with status `.pending` (a human/automated check approves it later).
@MainActor
@Observable
public final class DriverOnboardingViewModel {
    // Bound to the form fields.
    public var nidNumber: String = ""
    public var drivingLicenseNumber: String = ""
    public var vehicleType: VehicleType = .bike
    public var vehicleRegistrationPlate: String = ""
    public private(set) var isLoading: Bool = false
    public private(set) var errorMessage: String?

    /// Which user these documents belong to.
    @ObservationIgnored private let userId: String
    @ObservationIgnored private let repository: IAuthRepository
    @ObservationIgnored private let onSubmitted: (DriverVerification) -> Void
    @ObservationIgnored private let logger = AppLogger(category: "Auth")
    @ObservationIgnored private var isPreview = false

    public init(
        userId: String,
        initialVerification: DriverVerification? = nil,
        repository: IAuthRepository = AuthRepositoryFactory.make(),
        onSubmitted: @escaping (DriverVerification) -> Void
    ) {
        self.userId = userId
        if let initialVerification {
            nidNumber = initialVerification.nidNumber
            drivingLicenseNumber = initialVerification.drivingLicenseNumber
            vehicleType = initialVerification.vehicleType
            vehicleRegistrationPlate = initialVerification.vehicleRegistrationPlate
        }
        self.repository = repository
        self.onSubmitted = onSubmitted
    }

    /// Validates the form, submits it, and reports the returned verification onward.
    public func didTapSubmit() {
        // Ignore taps while a request is already running (prevents duplicate submissions).
        guard !isLoading, !isPreview else { return }

        // Trim so a stray space doesn't make a valid number fail review, and uppercase the plate.
        let nid = nidNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let license = drivingLicenseNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let plate = vehicleRegistrationPlate.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        guard !nid.isEmpty, !license.isEmpty, !plate.isEmpty else {
            errorMessage = String(localized: "Please fill in all fields.")
            return
        }
        errorMessage = nil
        isLoading = true
        Task {
            do {
                let verification = DriverVerification(
                    nidNumber: nid,
                    drivingLicenseNumber: license,
                    vehicleType: vehicleType,
                    vehicleRegistrationPlate: plate
                )
                let submitted = try await repository.submitDriverVerification(verification, for: userId)
                isLoading = false
                onSubmitted(submitted)
            } catch {
                isLoading = false
                errorMessage = String(localized: "Could not submit verification. Please try again.")
                // Log the error only; never the NID or licence numbers.
                logger.error("submitDriverVerification failed: \(error.localizedDescription)")
            }
        }
    }
}

#if DEBUG
extension DriverOnboardingViewModel {
    /// Preview-only: fixed state, and taps never reach a repository.
    convenience init(
        isPreview: Bool,
        initialVerification: DriverVerification? = nil,
        isLoading: Bool = false,
        errorMessage: String? = nil
    ) {
        self.init(
            userId: "driver-1",
            initialVerification: initialVerification,
            repository: MockAuthRepository(),
            onSubmitted: { _ in }
        )
        self.isPreview = isPreview
        self.isLoading = isLoading
        self.errorMessage = errorMessage
    }
}
#endif
