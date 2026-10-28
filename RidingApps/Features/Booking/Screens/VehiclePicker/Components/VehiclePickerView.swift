import SwiftUI

/// Horizontal row of selectable vehicle cards.
public struct VehiclePickerView: View {
    private let selected: VehicleType
    private let onSelect: (VehicleType) -> Void

    public init(selected: VehicleType, onSelect: @escaping (VehicleType) -> Void) {
        self.selected = selected
        self.onSelect = onSelect
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(VehicleType.allCases) { vehicleType in
                    card(for: vehicleType)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func card(for vehicleType: VehicleType) -> some View {
        let isSelected = vehicleType == selected
        return Button {
            onSelect(vehicleType)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: vehicleType.systemImageName)
                    .font(.system(size: 28))
                Text(vehicleType.displayName)
                    .font(BrandTypography.headline)
                Text("Up to \(vehicleType.capacity)")
                    .font(BrandTypography.caption)
                    .foregroundStyle(BrandColor.textSecondary)
            }
            .frame(width: 110, height: 100)
            .foregroundStyle(isSelected ? Color.white : BrandColor.textPrimary)
            .background(isSelected ? BrandColor.primary : BrandColor.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? BrandColor.primaryDark : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG

#Preview("Car selected") {
    VehiclePickerView(selected: .car, onSelect: { _ in })
        .padding(.vertical)
}

#Preview("Bike selected") {
    VehiclePickerView(selected: .bike, onSelect: { _ in })
        .padding(.vertical)
}

#Preview("Premium selected") {
    VehiclePickerView(selected: .premium, onSelect: { _ in })
        .padding(.vertical)
}

#endif
