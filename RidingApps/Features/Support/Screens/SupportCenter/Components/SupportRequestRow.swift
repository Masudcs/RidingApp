import SwiftUI

/// One row in "Your Requests".
struct SupportRequestRow: View {
    let categoryName: String
    let message: String
    let submittedAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(categoryName)
                .font(BrandTypography.headline)
            Text(message)
                .font(BrandTypography.caption)
                .foregroundStyle(BrandColor.textSecondary)
            Text(submittedAt, style: .relative)
                .font(BrandTypography.caption)
                .foregroundStyle(BrandColor.textSecondary)
        }
        .padding(.vertical, 2)
    }
}

#if DEBUG

#Preview("Row") {
    List {
        ForEach(SupportRequest.mockList()) { request in
            SupportRequestRow(categoryName: request.category.displayName, message: request.message, submittedAt: request.submittedAt)
        }
    }
}

#Preview("Row - Dark") {
    List {
        ForEach(SupportRequest.mockList()) { request in
            SupportRequestRow(categoryName: request.category.displayName, message: request.message, submittedAt: request.submittedAt)
        }
    }
    .preferredColorScheme(.dark)
}

#endif
