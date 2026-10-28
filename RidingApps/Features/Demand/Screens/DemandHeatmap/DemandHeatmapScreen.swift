import SwiftUI
import MapKit

/// Adapts a zone to the `Identifiable` annotation type the iOS 16 `Map` API needs.
private struct DemandZonePin: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let zone: DemandZone
}

/// Driver-tab map of high-demand areas with a legend, refresh button and a detail sheet per zone.
public struct DemandHeatmapScreen: View {
    @State private var viewModel: DemandHeatmapViewModel

    public init(viewModel: DemandHeatmapViewModel? = nil) {
        _viewModel = State(wrappedValue: viewModel ?? DemandHeatmapViewModel())
    }

    private var pins: [DemandZonePin] {
        viewModel.zones.map { zone in
            DemandZonePin(id: zone.id, coordinate: zone.center.coordinate, zone: zone)
        }
    }

    public var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            ZStack(alignment: .top) {
                // iOS16-compatible Map API: the trailing-closure `Map { }` / `Marker` builders are
                // iOS17+ only, but this package targets iOS 16.
                Map(coordinateRegion: $viewModel.region, annotationItems: pins) { pin in
                    MapAnnotation(coordinate: pin.coordinate) {
                        DemandZoneMarker(intensity: pin.zone.intensity) {
                            viewModel.didTapZone(pin.zone)
                        }
                    }
                }
                .ignoresSafeArea()

                VStack {
                    header
                    Spacer()
                    HStack(alignment: .bottom) {
                        DemandLegendCard()
                        Spacer()
                    }
                    .padding()
                }

                if viewModel.isLoading {
                    ProgressView()
                        .padding(12)
                        .background(BrandColor.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .navigationTitle("Demand Heatmap")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.didTapRefresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh demand heatmap")
                }
            }
            .task {
                await viewModel.load()
            }
            .sheet(item: $viewModel.selectedZone) { zone in
                DemandZoneDetailView(
                    title: zone.label,
                    intensity: zone.intensity,
                    demandText: viewModel.demandText(for: zone),
                    tripsText: viewModel.tripsText(for: zone)
                )
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Head to these areas for more ride requests")
                .font(BrandTypography.headline)
                .foregroundStyle(BrandColor.textPrimary)

            if let errorMessage = viewModel.errorMessage {
                ErrorBanner(errorMessage)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandColor.background.opacity(0.9))
    }
}

#if DEBUG

#Preview("Loading") {
    DemandHeatmapScreen(viewModel: DemandHeatmapViewModel(isPreview: true, isLoading: true))
}

#Preview("Data") {
    DemandHeatmapScreen(viewModel: DemandHeatmapViewModel(isPreview: true))
}

#Preview("Empty") {
    DemandHeatmapScreen(viewModel: DemandHeatmapViewModel(isPreview: true, isEmptyView: true))
}

#Preview("Error") {
    DemandHeatmapScreen(viewModel: DemandHeatmapViewModel(isPreview: true, isError: true))
}

#Preview("Zone selected") {
    DemandHeatmapScreen(viewModel: DemandHeatmapViewModel(isPreview: true, hasSelectedZone: true))
}

#endif
