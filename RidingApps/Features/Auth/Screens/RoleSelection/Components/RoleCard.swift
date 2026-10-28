import SwiftUI

/// One tappable row (icon, title, description) on the role selection screen.
struct RoleCard: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        SectionCard {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 32))
                    .foregroundStyle(BrandColor.primary)
                    .frame(width: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(BrandTypography.title)
                        .foregroundStyle(BrandColor.textPrimary)
                    Text(subtitle)
                        .font(BrandTypography.caption)
                        .foregroundStyle(BrandColor.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(BrandColor.textSecondary)
            }
        }
    }
}

#if DEBUG

#Preview("Rider") {
    RoleCard(title: "I'm a Rider", subtitle: "Book trips and get around the city.", systemImage: "person.fill")
        .padding()
        .background(BrandColor.background)
}

#Preview("Driver") {
    RoleCard(title: "I'm a Driver", subtitle: "Earn money by giving rides.", systemImage: "steeringwheel")
        .padding()
        .background(BrandColor.background)
}

#endif
