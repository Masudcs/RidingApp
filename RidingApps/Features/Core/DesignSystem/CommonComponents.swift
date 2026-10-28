import SwiftUI

/// Full-width filled button. `isLoading` shows a spinner and blocks taps; `isEnabled` dims it.
/// `title` is looked up as a localization key.
public struct PrimaryButton: View {
    private let title: String
    private let systemImage: String?
    private let isLoading: Bool
    private let isEnabled: Bool
    private let action: () -> Void

    public init(
        _ title: String,
        systemImage: String? = nil,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(LocalizedStringKey(title))
                    .font(BrandTypography.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(isEnabled ? BrandColor.primary : BrandColor.primary.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(!isEnabled || isLoading)
    }
}

/// Full-width tinted button for lower-priority actions next to a `PrimaryButton`.
public struct SecondaryButton: View {
    private let title: String
    private let systemImage: String?
    private let action: () -> Void

    public init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(LocalizedStringKey(title))
                    .font(BrandTypography.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(BrandColor.primary)
            .background(BrandColor.primary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

/// Rounded grouped-background container for a block of related content.
public struct SectionCard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(16)
            .background(BrandColor.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Inline red error strip. `message` is looked up as a localization key, so pass an
/// already-localized string (or a key).
public struct ErrorBanner: View {
    private let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(LocalizedStringKey(message))
                .font(BrandTypography.caption)
        }
        .foregroundStyle(BrandColor.danger)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandColor.danger.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#if DEBUG

#Preview("PrimaryButton") {
    VStack(spacing: 12) {
        PrimaryButton("Continue", systemImage: "arrow.right") {}
        PrimaryButton("Loading", isLoading: true) {}
        PrimaryButton("Disabled", isEnabled: false) {}
    }
    .padding()
}

#Preview("PrimaryButton - Dark") {
    VStack(spacing: 12) {
        PrimaryButton("Continue", systemImage: "arrow.right") {}
        PrimaryButton("Loading", isLoading: true) {}
        PrimaryButton("Disabled", isEnabled: false) {}
    }
    .padding()
    .background(BrandColor.background)
    .preferredColorScheme(.dark)
}

#Preview("SecondaryButton") {
    VStack(spacing: 12) {
        SecondaryButton("Add", systemImage: "plus") {}
        SecondaryButton("Cancel") {}
    }
    .padding()
}

#Preview("SecondaryButton - Dark") {
    VStack(spacing: 12) {
        SecondaryButton("Add", systemImage: "plus") {}
        SecondaryButton("Cancel") {}
    }
    .padding()
    .background(BrandColor.background)
    .preferredColorScheme(.dark)
}

#Preview("SectionCard") {
    SectionCard {
        VStack(alignment: .leading, spacing: 4) {
            Text("Gulshan 1 to Dhanmondi 27")
                .font(BrandTypography.headline)
            Text("Estimated fare 220")
                .font(BrandTypography.caption)
                .foregroundStyle(BrandColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding()
}

#Preview("SectionCard - Dark") {
    SectionCard {
        VStack(alignment: .leading, spacing: 4) {
            Text("Gulshan 1 to Dhanmondi 27")
                .font(BrandTypography.headline)
            Text("Estimated fare 220")
                .font(BrandTypography.caption)
                .foregroundStyle(BrandColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding()
    .background(BrandColor.background)
    .preferredColorScheme(.dark)
}

#Preview("ErrorBanner") {
    ErrorBanner("Couldn't load your trips. Please try again.")
        .padding()
}

#Preview("ErrorBanner - Dark") {
    ErrorBanner("Couldn't load your trips. Please try again.")
        .padding()
        .background(BrandColor.background)
        .preferredColorScheme(.dark)
}

#endif
