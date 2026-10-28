import SwiftUI

/// "Search for an address" row that opens the address search sheet.
public struct LocationSearchRow: View {
    private let title: LocalizedStringKey
    private let action: () -> Void

    public init(title: LocalizedStringKey, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Label(title, systemImage: "magnifyingglass")
                .foregroundStyle(BrandColor.primary)
        }
    }
}

#if DEBUG

#Preview("Default") {
    List {
        LocationSearchRow(title: "Search for an address", action: {})
    }
}

#endif
