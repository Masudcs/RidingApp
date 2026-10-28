import SwiftUI

/// Tappable suggestion row with a checkmark when it is the current choice.
public struct LocationRow: View {
    private let title: String
    private let subtitle: String
    private let isSelected: Bool
    private let action: () -> Void

    public init(title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(BrandTypography.body)
                        .foregroundStyle(BrandColor.textPrimary)
                    Text(subtitle)
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
        LocationRow(title: "Gulshan 1", subtitle: "Gulshan Avenue, Dhaka", isSelected: false, action: {})
    }
}

#Preview("Selected") {
    List {
        LocationRow(title: "Gulshan 1", subtitle: "Gulshan Avenue, Dhaka", isSelected: true, action: {})
    }
}

#Preview("Long text") {
    List {
        LocationRow(
            title: "Bangabandhu International Conference Center, Agargaon Administrative Area",
            subtitle: "Sher-e-Bangla Nagar, Agargaon, Dhaka, Bangladesh",
            isSelected: true,
            action: {}
        )
    }
}

#endif
