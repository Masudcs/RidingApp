import SwiftUI
import MapKit

/// Drives the driver's demand map: loads busy areas and shows them as colored markers so the
/// driver knows where ride requests are likely.
@MainActor @Observable
public final class DemandHeatmapViewModel {
    public private(set) var state: UIState<[DemandZone]> = .loading
    /// Kept separately from `state` so a failed refresh doesn't wipe the zones already on the map.
    public private(set) var zones: [DemandZone] = []
    /// The zone whose detail sheet is open.
    public var selectedZone: DemandZone?
    public var region: MKCoordinateRegion

    /// Guards against overlapping loads (refresh tapped while one is running).
    @ObservationIgnored private var isFetching = false
    @ObservationIgnored private let repository: IDemandRepository
    @ObservationIgnored private let logger = AppLogger(category: "Demand")
    #if DEBUG
    /// Set by the preview initializer so the screen's `.task` and refresh cannot overwrite the fake state.
    @ObservationIgnored private var isPreview = false
    #endif

    public init(repository: IDemandRepository = DemandRepository.makeDefault()) {
        self.repository = repository
        self.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 23.7935, longitude: 90.4046),
            span: MKCoordinateSpan(latitudeDelta: 0.22, longitudeDelta: 0.22)
        )
    }

    public var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    public var errorMessage: String? {
        if case let .error(message) = state { return message }
        return nil
    }

    /// Fetches zones and replaces the map data. Skipped if a load is already running. On failure
    /// the previous zones stay on the map and only the error banner changes.
    public func load() async {
        #if DEBUG
        guard !isPreview else { return }
        #endif
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }
        state = .loading
        do {
            zones = try await repository.fetchDemandZones()
            state = .data(data: zones)
            // Zone ids change between fetches; drop a sheet that points at a zone that's gone.
            if let selected = selectedZone, !zones.contains(where: { $0.id == selected.id }) {
                selectedZone = nil
            }
            logger.info("Loaded \(self.zones.count) demand zones")
        } catch {
            state = .error(message: String(localized: "Couldn't load the demand heatmap. Please try again."))
            logger.error("Failed to load demand zones: \(error.localizedDescription)")
        }
    }

    /// Refresh button; safe to tap repeatedly because `load()` ignores overlapping calls.
    public func didTapRefresh() {
        Task { await load() }
    }

    public func didTapZone(_ zone: DemandZone) {
        selectedZone = zone
    }

    public func demandText(for zone: DemandZone) -> String {
        switch zone.intensity {
        case .low: return String(localized: "Low demand")
        case .medium: return String(localized: "Medium demand")
        case .high: return String(localized: "High demand")
        }
    }

    public func tripsText(for zone: DemandZone) -> String {
        String(localized: "~\(zone.estimatedTripsPerHour) trips/hour")
    }
}

#if DEBUG

extension DemandHeatmapViewModel {
    /// Fixed fake state for previews; `load()` and refresh are disabled. `isPreview` has no default
    /// so a bare `DemandHeatmapViewModel()` keeps meaning the real initializer.
    convenience init(
        isPreview: Bool,
        isLoading: Bool = false,
        isError: Bool = false,
        isEmptyView: Bool = false,
        hasSelectedZone: Bool = false
    ) {
        self.init(repository: MockDemandRepository())
        self.isPreview = isPreview
        if isLoading {
            state = .loading
        } else if isError {
            state = .error(message: String(localized: "Couldn't load the demand heatmap. Please try again."))
        } else if isEmptyView {
            state = .data(data: [])
        } else {
            zones = DemandZone.mockList()
            state = .data(data: zones)
            if hasSelectedZone {
                selectedZone = zones.first
            }
        }
    }
}

#endif
