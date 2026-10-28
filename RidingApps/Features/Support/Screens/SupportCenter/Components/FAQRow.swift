import SwiftUI

/// Collapsible FAQ entry.
struct FAQRow: View {
    let question: String
    let answer: String

    var body: some View {
        DisclosureGroup(question) {
            Text(answer)
                .font(BrandTypography.body)
                .foregroundStyle(BrandColor.textSecondary)
        }
    }
}

#if DEBUG

#Preview("Collapsed") {
    List {
        FAQRow(question: FAQItem.all[0].question, answer: FAQItem.all[0].answer)
    }
}

#Preview("Several") {
    List {
        ForEach(FAQItem.all) { item in
            FAQRow(question: item.question, answer: item.answer)
        }
    }
}

#endif
