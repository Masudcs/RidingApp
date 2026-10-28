import SwiftUI

/// One selectable gender row; shows a checkmark when `isSelected`.
struct GenderOptionCard: View {
    let title: String
    let systemImage: String
    let isSelected: Bool

    var body: some View {
        SectionCard {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 24))
                    .foregroundStyle(BrandColor.primary)
                    .frame(width: 32)
                Text(title)
                    .font(BrandTypography.body)
                    .foregroundStyle(BrandColor.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(BrandColor.primary)
                }
            }
        }
    }
}

#if DEBUG

#Preview("Selected") {
    GenderOptionCard(title: "Female", systemImage: "person.fill", isSelected: true)
        .padding()
        .background(BrandColor.background)
}

#Preview("Unselected") {
    GenderOptionCard(title: "Prefer not to say", systemImage: "person.fill.questionmark", isSelected: false)
        .padding()
        .background(BrandColor.background)
}

#endif
