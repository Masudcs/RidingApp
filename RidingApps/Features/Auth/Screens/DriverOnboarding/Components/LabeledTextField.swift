import SwiftUI

/// A small caption above a text field; the label doubles as the placeholder.
struct LabeledTextField: View {
    let label: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(BrandTypography.caption)
                .foregroundStyle(BrandColor.textSecondary)
            TextField(label, text: $text)
                .keyboardType(keyboardType)
                .font(BrandTypography.body)
        }
    }
}

#if DEBUG

#Preview("Empty") {
    LabeledTextField(label: "National ID number", text: .constant(""), keyboardType: .numberPad)
        .padding()
}

#Preview("Filled") {
    LabeledTextField(label: "Driving license number", text: .constant("DL-123456"))
        .padding()
}

#endif
