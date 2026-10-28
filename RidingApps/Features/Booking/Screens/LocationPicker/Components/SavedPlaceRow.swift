import SwiftUI

/// Like `LocationRow`, but led by the rider's own label ("Home") and a star.
public struct SavedPlaceRow: View {
    private let label: String
    private let title: String
    private let isSelected: Bool
    private let action: () -> Void

    public init(label: String, title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.label = label
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundStyle(BrandColor.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(BrandTypography.body)
                        .foregroundStyle(BrandColor.textPrimary)
                    Text(title)
                        .font(BrandTypography.caption)
                        .foregroundStyle(BrandColor.textSecondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(BrandColor.primary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG

#Preview("Default") {
    List {
        SavedPlaceRow(label: "Home", title: "Gulshan 1", isSelected: false, action: {})
    }
}

#Preview("Selected") {
    List {
        SavedPlaceRow(label: "Home", title: "Gulshan 1", isSelected: true, action: {})
    }
}

#Preview("Long text") {
    List {
        SavedPlaceRow(
            label: "My grandmother's house near the old Dhaka market",
            title: "Bangabandhu International Conference Center, Agargaon Administrative Area",
            isSelected: true,
            action: {}
        )
    }
}

#endif
