import Combine
import Foundation
import MapKit
import Observation

/// State for the live trip screen (rider or driver side): driver position, ETA, status text,
/// route-deviation / stall detection, silent SOS and the chat sheet.
///
/// Consumes the repository's driver-location stream; when that stream ends normally the trip is
/// over and `onTripCompleted` fires so the parent moves on to payment.
@MainActor
@Observable
public final class TripTrackingViewModel {
    public private(set) var driverInfo: TripDriverInfo?
    public private(set) var etaText: String
    /// Map camera. Bound to the map, so the view can write it; it follows the driver on each update.
    public var region: MKCoordinateRegion
    public private(set) var tripStatusText: String
    /// Temporary warning banner; auto-hides after a few seconds.
    public private(set) var deviationBannerText: String?
    public private(set) var isSilentSOSListening = false
    public var isShowingChat = false
    /// True after repeated poll failures; cleared when polling recovers.
    public private(set) var isConnectionProblem = false

    /// Text for the small connection banner, or nil while the connection is fine.
    public var connectionBannerText: String? {
        isConnectionProblem ? String(localized: "Connection problem. Retrying...") : nil
    }

    public let trip: Trip
    public let currentUserId: String
    public let currentUserRole: UserRole
    /// How far (meters) the driver may be from the pickup->dropoff line before it counts as off route.
    public let offRouteThresholdMeters: Double
    /// How long the driver must stay put during a trip before a stall event is raised.
    public let stallThresholdSeconds: TimeInterval

    @ObservationIgnored private let repository: ITrackingRepository
    private let favoriteDriversStore: FavoriteDriversStore
    private let silentSOSListener: SilentSOSListener
    private let onTripCompleted: () -> Void
    private let onRouteDeviation: ((RouteDeviationEvent) -> Void)?
    @ObservationIgnored private let logger = AppLogger(category: "Tracking")
    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var connectionTask: Task<Void, Never>?
    @ObservationIgnored private var deviationBannerDismissTask: Task<Void, Never>?
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()
    /// Whether the user wants silent SOS on; lets us restart the listener when it stops by itself.
    @ObservationIgnored private var isSilentSOSEnabled = false
    /// Bumped whenever the (ObservableObject) favorites store changes so favorite/blocked state re-renders.
    private var favoritesRevision = 0

    private static let stallMovementThresholdMeters = 5.0

    // Deviation bookkeeping: each episode raises one event, and re-arms once the driver is back on
    // route / moving again, so the contact is not spammed on every location update.
    @ObservationIgnored private var isOffRouteEventActive = false
    @ObservationIgnored private var stallEpisodeStartedAt: Date?
    @ObservationIgnored private var stallEventFiredForCurrentEpisode = false
    @ObservationIgnored private var previousLocation: GeoPoint?
    @ObservationIgnored private var previousEmissionTime: Date?
    @ObservationIgnored private var hasNotifiedDriverArriving = false
    #if DEBUG
    /// Set by the preview initializer so streams, timers and the SOS listener never start behind a preview.
    @ObservationIgnored private var isPreview = false
    #endif

    public init(
        trip: Trip,
        currentUserId: String = "",
        currentUserRole: UserRole = .rider,
        favoriteDriversStore: FavoriteDriversStore? = nil,
        repository: ITrackingRepository = AppEnvironment.current.usesMockServices ? MockTrackingRepository() : TrackingRepository(),
        safetyRepository: ISafetyRepository = AppEnvironment.current.usesMockServices ? MockSafetyRepository.shared : SafetyRepository(),
        offRouteThresholdMeters: Double = 400,
        stallThresholdSeconds: TimeInterval = 45,
        onTripCompleted: @escaping () -> Void = {},
        onRouteDeviation: ((RouteDeviationEvent) -> Void)? = nil
    ) {
        self.trip = trip
        self.currentUserId = currentUserId
        self.currentUserRole = currentUserRole
        self.repository = repository
        self.favoriteDriversStore = favoriteDriversStore ?? FavoriteDriversStore()
        self.silentSOSListener = SilentSOSListener(repository: safetyRepository, codeword: SilentSOSPreferences.codeword)
        self.offRouteThresholdMeters = offRouteThresholdMeters
        self.stallThresholdSeconds = stallThresholdSeconds
        self.onTripCompleted = onTripCompleted
        self.onRouteDeviation = onRouteDeviation
        self.driverInfo = trip.driver
        self.tripStatusText = Self.statusText(for: trip.status)
        self.etaText = Self.etaText(for: trip.driver?.etaMinutes)

        let center = (trip.driver?.currentLocation ?? trip.pickup.point).coordinate
        self.region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )

        self.favoriteDriversStore.objectWillChange
            .sink { [weak self] _ in self?.favoritesRevision += 1 }
            .store(in: &cancellables)
        silentSOSListener.$isListening
            .sink { [weak self] in self?.isSilentSOSListening = $0 }
            .store(in: &cancellables)
    }

    // MARK: - Derived state

    /// Pickup, dropoff, numbered stops and the driver, in the order they are drawn.
    var pins: [TrackingMapPin] {
        var items: [TrackingMapPin] = [
            TrackingMapPin(id: "pickup", coordinate: trip.pickup.point.coordinate, kind: .pickup),
            TrackingMapPin(id: "dropoff", coordinate: trip.dropoff.point.coordinate, kind: .dropoff)
        ]
        for (index, stop) in trip.stops.enumerated() {
            items.append(TrackingMapPin(id: "stop-\(stop.id)", coordinate: stop.point.coordinate, kind: .stop(index + 1)))
        }
        if let driverInfo {
            items.append(
                TrackingMapPin(
                    id: "driver-\(driverInfo.driverId)",
                    coordinate: driverInfo.currentLocation.coordinate,
                    kind: .driver(driverInfo.vehicleType)
                )
            )
        }
        return items
    }

    /// Text handed to the share sheet so the rider can send trip details to someone.
    public var shareSummary: String {
        let driverName = driverInfo?.name ?? String(localized: "your driver")
        let etaMinutes = driverInfo?.etaMinutes ?? 0
        return String(localized: "Tracking my ride: \(trip.pickup.title) to \(trip.dropoff.title), driver \(driverName), ETA \(etaMinutes) min")
    }

    public var isDriver: Bool {
        currentUserRole == .driver
    }

    /// Only riders can favorite/block the driver they're riding with.
    public var canManageDriver: Bool {
        currentUserRole == .rider
    }

    public var isDriverFavorite: Bool {
        _ = favoritesRevision
        return driverInfo.map { favoriteDriversStore.isFavorite($0.driverId) } ?? false
    }

    public var isDriverBlocked: Bool {
        _ = favoritesRevision
        return driverInfo.map { favoriteDriversStore.isBlocked($0.driverId) } ?? false
    }

    /// Before pickup the driver needs directions to the rider; once the trip is under way, to the
    /// next stop (or straight to the dropoff if there are none left).
    private var driverNavigationDestination: NamedLocation {
        switch trip.status {
        case .inProgress:
            return trip.stops.first ?? trip.dropoff
        default:
            return trip.pickup
        }
    }

    // MARK: - Actions

    /// Starts following the driver and (if enabled) silent SOS. Called whenever the screen shows,
    /// so it replaces any stream from a previous appearance.
    ///
    /// `onTripCompleted` is invoked from here (rather than left to the view) because the
    /// AsyncStream's finish event is only observable from inside the consuming Task. A cancelled
    /// stream also ends, so it is not reported as completion.
    public func onAppear(currentLocation: GeoPoint?) {
        #if DEBUG
        guard !isPreview else { return }
        #endif
        streamTask?.cancel()
        connectionTask?.cancel()
        connectionTask = Task { [weak self, repository] in
            for await hasProblem in repository.connectionProblemStream() {
                guard let self else { return }
                await self.setConnectionProblem(hasProblem)
            }
        }
        streamTask = Task { [weak self, trip, repository, onTripCompleted] in
            guard let self else { return }
            for await info in repository.streamDriverLocation(trip: trip) {
                await self.apply(info)
            }
            guard !Task.isCancelled else { return }
            onTripCompleted()
        }
        isSilentSOSEnabled = SilentSOSPreferences.isEnabled
        if isSilentSOSEnabled {
            startSilentSOSListening(currentLocation: currentLocation)
        }
    }

    /// Stops everything that keeps running in the background (location stream, SOS listener,
    /// banner timer). `onAppear` restarts it if the screen comes back.
    public func onDisappear() {
        #if DEBUG
        guard !isPreview else { return }
        #endif
        streamTask?.cancel()
        connectionTask?.cancel()
        isConnectionProblem = false
        deviationBannerDismissTask?.cancel()
        isSilentSOSEnabled = false
        silentSOSListener.stop()
    }

    /// The listener can stop on its own (e.g. after sending an alert); restart it while the screen is up.
    public func silentSOSListeningDidChange(isListening: Bool, currentLocation: GeoPoint?) {
        #if DEBUG
        guard !isPreview else { return }
        #endif
        guard !isListening, isSilentSOSEnabled else { return }
        startSilentSOSListening(currentLocation: currentLocation)
    }

    public func didTapChat() {
        isShowingChat = true
    }

    public func didTapCloseChat() {
        isShowingChat = false
    }

    public func didTapDirections() {
        MapsNavigation.openDirections(to: driverNavigationDestination)
    }

    public func didTapToggleFavorite() {
        guard let driverInfo else { return }
        favoriteDriversStore.toggleFavorite(driverId: driverInfo.driverId, name: driverInfo.name)
    }

    public func didTapToggleBlocked() {
        guard let driverInfo else { return }
        favoriteDriversStore.toggleBlocked(driverId: driverInfo.driverId, name: driverInfo.name)
    }

    private func startSilentSOSListening(currentLocation: GeoPoint?) {
        silentSOSListener.start(
            tripId: trip.id,
            role: currentUserRole,
            location: currentLocation ?? trip.pickup.point
        )
    }

    private func setConnectionProblem(_ hasProblem: Bool) {
        isConnectionProblem = hasProblem
    }

    /// Applies one driver update: deviation checks, "arriving" notification, ETA and map position.
    private func apply(_ info: TripDriverInfo) {
        evaluateRouteDeviation(at: info.currentLocation, timestamp: Date())
        if currentUserRole == .rider, !hasNotifiedDriverArriving, info.etaMinutes <= 1 {
            hasNotifiedDriverArriving = true
            LocalNotifications.notify(
                title: String(localized: "Your driver is arriving"),
                body: String(localized: "\(info.name) is almost at your pickup point.")
            )
        }
        driverInfo = info
        etaText = Self.etaText(for: info.etaMinutes)
        region.center = info.currentLocation.coordinate
        logger.debug("Driver \(info.driverId) moved, ETA \(info.etaMinutes) min")
    }

    private func evaluateRouteDeviation(at location: GeoPoint, timestamp: Date) {
        evaluateOffRoute(at: location)
        evaluateStall(at: location, timestamp: timestamp)
    }

    /// Compares against the straight pickup->dropoff line (a rough proxy until the server sends the real route).
    private func evaluateOffRoute(at location: GeoPoint) {
        let distance = RouteDeviationMath.perpendicularDistanceMeters(
            from: location,
            segmentStart: trip.pickup.point,
            segmentEnd: trip.dropoff.point
        )

        guard distance > offRouteThresholdMeters else {
            isOffRouteEventActive = false
            return
        }

        guard !isOffRouteEventActive else { return }
        isOffRouteEventActive = true
        emit(.offRoute(distanceMeters: distance), at: location)
    }

    /// Stall = driver barely moved for `stallThresholdSeconds` while the trip is in progress.
    private func evaluateStall(at location: GeoPoint, timestamp: Date) {
        defer {
            previousLocation = location
            previousEmissionTime = timestamp
        }

        guard trip.status == .inProgress,
              let previousLocation,
              let previousEmissionTime,
              previousLocation.distance(to: location) <= Self.stallMovementThresholdMeters
        else {
            stallEpisodeStartedAt = nil
            stallEventFiredForCurrentEpisode = false
            return
        }

        let episodeStart = stallEpisodeStartedAt ?? previousEmissionTime
        stallEpisodeStartedAt = episodeStart
        let stalledSeconds = timestamp.timeIntervalSince(episodeStart)

        guard stalledSeconds >= stallThresholdSeconds, !stallEventFiredForCurrentEpisode else { return }
        stallEventFiredForCurrentEpisode = true
        emit(.stalled(seconds: stalledSeconds), at: location)
    }

    private func emit(_ kind: RouteDeviationEvent.Kind, at location: GeoPoint) {
        let event = RouteDeviationEvent(tripId: trip.id, location: location, kind: kind)
        handleRouteDeviation(event)
    }

    private func handleRouteDeviation(_ event: RouteDeviationEvent) {
        onRouteDeviation?(event)

        deviationBannerDismissTask?.cancel()
        deviationBannerText = Self.bannerText(for: event.kind)
        deviationBannerDismissTask = Task {
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled {
                deviationBannerText = nil
            }
        }
    }

    private static func bannerText(for kind: RouteDeviationEvent.Kind) -> String {
        switch kind {
        case .offRoute:
            return String(localized: "Route deviation detected — notifying your emergency contact")
        case .stalled:
            return String(localized: "Trip has been stationary for a while — checking in")
        }
    }

    private static func etaText(for minutes: Int?) -> String {
        guard let minutes else { return String(localized: "Locating driver...") }
        return minutes <= 0 ? String(localized: "Arriving now") : String(localized: "\(minutes) min away")
    }

    private static func statusText(for status: TripStatus) -> String {
        switch status {
        case .negotiating: return String(localized: "Negotiating fare")
        case .searchingDriver: return String(localized: "Searching for a driver")
        case .driverAssigned: return String(localized: "Driver assigned")
        case .driverArriving: return String(localized: "Driver is arriving")
        case .inProgress: return String(localized: "Trip in progress")
        case .completed: return String(localized: "Trip completed")
        case .cancelled: return String(localized: "Trip cancelled")
        }
    }
}

#if DEBUG

extension TripTrackingViewModel {
    /// Fixed fake state for previews; the location stream, connection polling and silent SOS are
    /// disabled. `isLoading` is the "no driver yet" state; `isError` shows the connection banner.
    convenience init(
        isPreview: Bool = true,
        isLoading: Bool = false,
        isError: Bool = false,
        status: TripStatus = .driverArriving,
        role: UserRole = .rider,
        withStops: Bool = false,
        hasDeviationWarning: Bool = false,
        isSilentSOSActive: Bool = false,
        isFavoriteDriver: Bool = false
    ) {
        let trip = Trip.mock(status: isLoading ? .searchingDriver : status, withStops: withStops)
        self.init(
            trip: trip,
            currentUserId: role == .rider ? "rider-1" : "driver-1",
            currentUserRole: role,
            favoriteDriversStore: TripTrackingViewModel.makePreviewFavoritesStore(favoriteDriver: isFavoriteDriver ? trip.driver : nil),
            repository: MockTrackingRepository(),
            safetyRepository: MockSafetyRepository.shared
        )
        self.isPreview = isPreview
        isConnectionProblem = isError
        isSilentSOSListening = isSilentSOSActive
        if hasDeviationWarning {
            deviationBannerText = Self.bannerText(for: .offRoute(distanceMeters: 650))
        }
    }

    /// Throwaway store (empty suite, preview owner id) so previews never write to a real user's favorites.
    private static func makePreviewFavoritesStore(favoriteDriver: TripDriverInfo?) -> FavoriteDriversStore {
        let suiteName = "RidingApps.preview.favoriteDrivers"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = FavoriteDriversStore(userId: "preview-user", defaults: defaults)
        if let favoriteDriver {
            store.toggleFavorite(driverId: favoriteDriver.driverId, name: favoriteDriver.name)
        }
        return store
    }
}

#endif
