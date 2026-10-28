import Foundation
import SwiftUI

/// Small capsule showing a driver's ID verification status and trust score.
public struct DriverVerificationBadge: View {
    private let verification: DriverVerification
    private let ratingAverage: Double

    public init(verification: DriverVerification, ratingAverage: Double) {
        self.verification = verification
        self.ratingAverage = ratingAverage
    }

    private var trustScore: Int {
        verification.trustScore(ratingAverage: ratingAverage, now: Date()).overall
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
            Text(label)
                .font(BrandTypography.caption)
            Text("Trust Score: \(trustScore)")
                .font(BrandTypography.caption)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private var iconName: String {
        switch verification.status {
        case .verified:
            return "checkmark.shield.fill"
        case .pending:
            return "clock.fill"
        case .rejected, .notSubmitted:
            return "exclamationmark.triangle.fill"
        }
    }

    private var label: String {
        switch verification.status {
        case .verified:
            return String(localized: "Verified driver")
        case .pending:
            return String(localized: "Verification pending")
        case .rejected:
            return String(localized: "Verification rejected")
        case .notSubmitted:
            return String(localized: "Not verified")
        }
    }

    private var color: Color {
        switch verification.status {
        case .verified:
            return BrandColor.success
        case .pending:
            return BrandColor.warning
        case .rejected, .notSubmitted:
            return BrandColor.danger
        }
    }
}

#if DEBUG

#Preview("Verified") {
    DriverVerificationBadge(verification: .mock(status: .verified), ratingAverage: 4.9)
        .padding()
}

#Preview("Pending") {
    DriverVerificationBadge(verification: .mock(status: .pending), ratingAverage: 4.5)
        .padding()
}

#Preview("Rejected") {
    DriverVerificationBadge(verification: .mock(status: .rejected), ratingAverage: 3.8)
        .padding()
}

#Preview("Not submitted") {
    DriverVerificationBadge(verification: .mock(status: .notSubmitted), ratingAverage: 5.0)
        .padding()
}

#Preview("Verified - Dark") {
    DriverVerificationBadge(verification: .mock(status: .verified), ratingAverage: 4.9)
        .padding()
        .background(BrandColor.background)
        .preferredColorScheme(.dark)
}

#endif
