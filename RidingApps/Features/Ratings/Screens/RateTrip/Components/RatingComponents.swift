import SwiftUI

/// Row of five tappable stars; tapping star N reports N (not a toggle).
struct StarRatingView: View {
    let stars: Int
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    onSelect(value)
                } label: {
                    Image(systemName: value <= stars ? "star.fill" : "star")
                        .font(.system(size: 32))
                        .foregroundStyle(value <= stars ? BrandColor.accent : BrandColor.textSecondary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(value == 1 ? String(localized: "Rate 1 star") : String(localized: "Rate \(value) stars"))
            }
        }
    }
}

/// Wrapping grid of toggleable tag chips.
struct RatingTagFlowView: View {
    let tags: [RatingTag]
    let selected: Set<RatingTag>
    let onToggle: (RatingTag) -> Void

    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 8, alignment: .leading)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(tags) { tag in
                let isSelected = selected.contains(tag)
                Button {
                    onToggle(tag)
                } label: {
                    Text(tag.displayName)
                        .font(BrandTypography.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(isSelected ? Color.white : BrandColor.textPrimary)
                        .background(isSelected ? BrandColor.primary : BrandColor.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#if DEBUG

#Preview("Stars: none selected") {
    StarRatingView(stars: 0, onSelect: { _ in })
        .padding()
}

#Preview("Stars: three") {
    StarRatingView(stars: 3, onSelect: { _ in })
        .padding()
}

#Preview("Stars: five") {
    StarRatingView(stars: 5, onSelect: { _ in })
        .padding()
}

#Preview("Tags: none selected") {
    RatingTagFlowView(
        tags: RatingTag.suggestions(forRatedRole: .driver, stars: 5),
        selected: [],
        onToggle: { _ in }
    )
    .padding()
}

#Preview("Tags: selected") {
    RatingTagFlowView(
        tags: RatingTag.suggestions(forRatedRole: .driver, stars: 5),
        selected: [.safeDriving, .onTime],
        onToggle: { _ in }
    )
    .padding()
}

#Preview("Tags: negative") {
    RatingTagFlowView(
        tags: RatingTag.suggestions(forRatedRole: .driver, stars: 1),
        selected: [.tookLongRoute],
        onToggle: { _ in }
    )
    .padding()
}

#endif
