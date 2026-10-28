import SwiftUI

/// Icon drawn for each `TrackingMapPin.Kind`.
struct TrackingMapPinView: View {
    let kind: TrackingMapPin.Kind

    var body: some View {
        switch kind {
        case .pickup:
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundStyle(BrandColor.success)
        case .dropoff:
            Image(systemName: "flag.circle.fill")
                .font(.title2)
                .foregroundStyle(BrandColor.danger)
        case .driver(let vehicleType):
            Image(systemName: vehicleType.systemImageName)
                .font(.title3)
                .padding(8)
                .background(Circle().fill(BrandColor.primary))
                .foregroundStyle(.white)
        case .stop(let number):
            Text("\(number)")
                .font(.caption.bold())
                .padding(6)
                .background(Circle().fill(BrandColor.accent))
                .foregroundStyle(.white)
        }
    }
}

#if DEBUG

#Preview("Pickup") {
    TrackingMapPinView(kind: .pickup)
        .padding()
}

#Preview("Dropoff") {
    TrackingMapPinView(kind: .dropoff)
        .padding()
}

#Preview("Stop") {
    TrackingMapPinView(kind: .stop(2))
        .padding()
}

#Preview("Driver") {
    HStack(spacing: 16) {
        ForEach(VehicleType.allCases) { vehicleType in
            TrackingMapPinView(kind: .driver(vehicleType))
        }
    }
    .padding()
}

#endif
