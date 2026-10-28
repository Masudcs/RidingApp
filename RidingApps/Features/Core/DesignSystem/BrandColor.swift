import SwiftUI

/// Brand palette shared by every feature module. Defined in code (not an asset catalog) so pure-
/// Swift package targets can reference it without carrying image assets.
public enum BrandColor {
    public static let primary = Color(red: 0.043, green: 0.541, blue: 0.318)      // deep green
    public static let primaryDark = Color(red: 0.020, green: 0.353, blue: 0.196)
    public static let accent = Color(red: 0.980, green: 0.694, blue: 0.078)       // rickshaw yellow
    public static let danger = Color(red: 0.827, green: 0.184, blue: 0.184)
    public static let warning = Color(red: 0.914, green: 0.588, blue: 0.078)
    public static let success = Color(red: 0.157, green: 0.612, blue: 0.361)
    public static let background = Color(.systemBackground)
    public static let secondaryBackground = Color(.secondarySystemBackground)
    public static let textPrimary = Color(.label)
    public static let textSecondary = Color(.secondaryLabel)
}

/// Shared fonts. Built on text styles so they scale with Dynamic Type.
public enum BrandTypography {
    public static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    public static let title = Font.system(.title2, design: .rounded, weight: .semibold)
    public static let headline = Font.system(.headline, design: .rounded)
    public static let body = Font.system(.body)
    public static let caption = Font.system(.caption)
}

#if DEBUG

#Preview("Brand palette") {
    VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 8) {
            ForEach(
                [BrandColor.primary, BrandColor.primaryDark, BrandColor.accent, BrandColor.danger, BrandColor.warning, BrandColor.success],
                id: \.self
            ) { color in
                RoundedRectangle(cornerRadius: 8).fill(color).frame(height: 56)
            }
        }
        Text("Large title").font(BrandTypography.largeTitle)
        Text("Title").font(BrandTypography.title)
        Text("Headline").font(BrandTypography.headline)
        Text("Body").font(BrandTypography.body)
        Text("Caption").font(BrandTypography.caption).foregroundStyle(BrandColor.textSecondary)
    }
    .padding()
}

#Preview("Brand palette - Dark") {
    VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 8) {
            ForEach(
                [BrandColor.primary, BrandColor.primaryDark, BrandColor.accent, BrandColor.danger, BrandColor.warning, BrandColor.success],
                id: \.self
            ) { color in
                RoundedRectangle(cornerRadius: 8).fill(color).frame(height: 56)
            }
        }
        Text("Large title").font(BrandTypography.largeTitle)
        Text("Title").font(BrandTypography.title)
        Text("Headline").font(BrandTypography.headline)
        Text("Body").font(BrandTypography.body)
        Text("Caption").font(BrandTypography.caption).foregroundStyle(BrandColor.textSecondary)
    }
    .padding()
    .background(BrandColor.background)
    .preferredColorScheme(.dark)
}

#endif
