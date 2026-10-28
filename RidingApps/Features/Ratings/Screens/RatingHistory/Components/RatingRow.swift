import SwiftUI

/// One history row: stars, date, optional comment and tag names.
struct RatingRow: View {
    let rating: Rating

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { value in
                        Image(systemName: value <= rating.stars ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundStyle(BrandColor.accent)
                    }
                }
                Spacer()
                Text(rating.createdAt, style: .date)
                    .font(BrandTypography.caption)
                    .foregroundStyle(BrandColor.textSecondary)
            }

            if let comment = rating.comment {
                Text(comment)
                    .font(BrandTypography.body)
            }

            if !rating.tags.isEmpty {
                Text(rating.tags.map(\.displayName).joined(separator: " \u{00B7} "))
                    .font(BrandTypography.caption)
                    .foregroundStyle(BrandColor.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG

#Preview("Comment and tags") {
    RatingRow(rating: .mock())
        .padding()
}

#Preview("Stars only") {
    RatingRow(rating: .mock(stars: 4, comment: nil, tags: []))
        .padding()
}

#Preview("Low rating") {
    RatingRow(rating: .mock(stars: 1, comment: "Took a longer route than needed.", tags: [.tookLongRoute, .lateArrival]))
        .padding()
}

#Preview("Long text") {
    RatingRow(rating: .mock(
        comment: "The driver was on time, kept the car spotless and took a sensible route through heavy traffic. He also helped carry my bags up to the third floor without being asked.",
        tags: [.safeDriving, .cleanVehicle, .onTime, .friendly, .greatConversation]
    ))
    .padding()
}

#endif
