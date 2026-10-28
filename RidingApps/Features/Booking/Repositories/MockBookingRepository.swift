import Foundation

/// A stable driver identity, unlike the per-trip `TripDriverInfo` (vehicle/ETA/location change
/// every ride). Favoriting/blocking only means something if the same driver can be matched again.
private struct DriverProfile {
    let id: String
    let name: String
    let gender: Gender
}

/// Offline stand-in for the backend (Dev/Staging). Keeps trips in memory and fakes latency,
/// surge, counter-offers and driver matching with random values, so results differ per run.
public actor MockBookingRepository: IBookingRepository {
    /// Every trip created this session, by id. Cancelled trips are removed.
    private var trips: [String: Trip] = [:]

    private let dhakaLocations: [NamedLocation] = [
        NamedLocation(title: "Gulshan 1 Circle", subtitle: "Gulshan, Dhaka", point: GeoPoint(latitude: 23.7809, longitude: 90.4155)),
        NamedLocation(title: "Dhanmondi 27", subtitle: "Dhanmondi, Dhaka", point: GeoPoint(latitude: 23.7461, longitude: 90.3742)),
        NamedLocation(title: "Bashundhara City", subtitle: "Panthapath, Dhaka", point: GeoPoint(latitude: 23.7509, longitude: 90.3925)),
        NamedLocation(title: "Motijheel", subtitle: "Motijheel C/A, Dhaka", point: GeoPoint(latitude: 23.7332, longitude: 90.4172)),
        NamedLocation(title: "Uttara Sector 7", subtitle: "Uttara, Dhaka", point: GeoPoint(latitude: 23.8747, longitude: 90.3987))
    ]

    private let surgeReasons = [
        "High demand in your area",
        "Rain in your area",
        "Limited drivers nearby",
        "Rush hour traffic"
    ]

    private let riderNamePool = [
        "Tania Ahmed", "Mizanur Rahman", "Sabrina Islam", "Kamal Hossain", "Nusrat Jahan"
    ]

    private let driverPool: [DriverProfile] = [
        DriverProfile(id: "drv-karim", name: "Karim Rahman", gender: .male),
        DriverProfile(id: "drv-abul", name: "Abul Hossain", gender: .male),
        DriverProfile(id: "drv-selim", name: "Selim Mia", gender: .male),
        DriverProfile(id: "drv-jasim", name: "Jasim Uddin", gender: .male),
        DriverProfile(id: "drv-rafiq", name: "Rafiq Islam", gender: .male),
        DriverProfile(id: "drv-nasrin", name: "Nasrin Akter", gender: .female),
        DriverProfile(id: "drv-farida", name: "Farida Yasmin", gender: .female),
        DriverProfile(id: "drv-shirin", name: "Shirin Sultana", gender: .female),
        DriverProfile(id: "drv-ruma", name: "Ruma Begum", gender: .female),
        DriverProfile(id: "drv-taslima", name: "Taslima Khatun", gender: .female)
    ]

    private var favoriteDriverIds: Set<String> = []
    private var blockedDriverIds: Set<String> = []

    public init() {}

    public func nearbyPickupSuggestions() async throws -> [NamedLocation] {
        await MockLatency.short()
        return dhakaLocations
    }

    public func dropoffSuggestions(near pickup: NamedLocation) async throws -> [NamedLocation] {
        await MockLatency.short()
        return dhakaLocations
            .filter { $0.id != pickup.id }
            .sorted { $0.point.distance(to: pickup.point) < $1.point.distance(to: pickup.point) }
    }

    public func estimateFare(
        vehicleType: VehicleType,
        pickup: NamedLocation,
        stops: [NamedLocation],
        dropoff: NamedLocation
    ) async throws -> (suggestedFare: Money, surge: SurgeContext) {
        await MockLatency.short()
        let distanceKm = Self.routeDistanceKm(pickup: pickup, stops: stops, dropoff: dropoff)
        let stopsFee = FarePricing.perStopFee * Double(stops.count)
        let baseTotal = vehicleType.baseFare + (vehicleType.baseFarePerKm * distanceKm) + stopsFee

        guard Double.random(in: 0...1) < 0.3 else {
            return (baseTotal, .none)
        }

        let multiplier = Double.random(in: 1.2...1.8)
        let reason = surgeReasons.randomElement() ?? surgeReasons[0]
        let surge = SurgeContext(multiplier: multiplier, reasons: [reason])
        return (baseTotal * multiplier, surge)
    }

    private static func routeDistanceKm(pickup: NamedLocation, stops: [NamedLocation], dropoff: NamedLocation) -> Double {
        let waypoints = [pickup] + stops + [dropoff]
        var totalMeters = 0.0
        for index in 0..<(waypoints.count - 1) {
            totalMeters += waypoints[index].point.distance(to: waypoints[index + 1].point)
        }
        return totalMeters / 1000
    }

    public func createNegotiation(
        vehicleType: VehicleType,
        pickup: NamedLocation,
        stops: [NamedLocation],
        dropoff: NamedLocation,
        suggestedFare: Money,
        surge: SurgeContext,
        womenSafeModeRequested: Bool,
        riderId: String,
        riderName: String
    ) async throws -> Trip {
        await MockLatency.short()
        let trip = Trip(
            status: .negotiating,
            vehicleType: vehicleType,
            pickup: pickup,
            stops: stops,
            dropoff: dropoff,
            suggestedFare: suggestedFare,
            surgeContext: surge,
            offers: [FareOffer(author: .rider, amount: suggestedFare, createdAt: Date())],
            insurancePremium: defaultInsurancePremium,
            womenSafeModeRequested: womenSafeModeRequested,
            riderId: riderId,
            riderName: riderName
        )
        trips[trip.id] = trip
        return trip
    }

    /// Randomly either the driver counters (+-10% of suggested) or accepts and gets matched.
    public func submitRiderOffer(tripId: String, amount: Money) async throws -> Trip {
        guard var trip = trips[tripId] else { throw BookingError.tripNotFound }
        trip.offers.append(FareOffer(author: .rider, amount: amount, createdAt: Date()))
        trips[tripId] = trip

        await MockLatency.short()

        if Bool.random() {
            let counterFactor = Double.random(in: 0.9...1.1)
            let counterAmount = trip.suggestedFare * counterFactor
            trip.offers.append(FareOffer(author: .driver, amount: counterAmount, createdAt: Date()))
            trips[tripId] = trip
        } else {
            trip.status = .searchingDriver
            trips[tripId] = trip

            await MockLatency.short()

            trip.driver = await matchDriver(vehicleType: trip.vehicleType, womenSafeModeRequested: trip.womenSafeModeRequested)
            trip.status = .driverAssigned
            trip.agreedFare = amount
            trip.driverAssignedAt = Date()
            trips[tripId] = trip
        }

        return trip
    }

    public func respondToOffer(tripId: String, response: OfferResponse) async throws -> Trip {
        guard var trip = trips[tripId] else { throw BookingError.tripNotFound }
        await MockLatency.short()

        switch response {
        case .accept:
            let latestRiderOffer = trip.offers.last { $0.author == .rider }?.amount ?? trip.suggestedFare
            trip.agreedFare = latestRiderOffer
            trip.driver = await matchDriver(vehicleType: trip.vehicleType, womenSafeModeRequested: trip.womenSafeModeRequested)
            trip.status = .driverAssigned
            trip.driverAssignedAt = Date()
        case .counter(let amount):
            trip.offers.append(FareOffer(author: .driver, amount: amount, createdAt: Date()))
        case .decline:
            trip.status = .cancelled
        }

        trips[tripId] = trip
        return trip
    }

    public func riderAcceptsOffer(tripId: String) async throws -> Trip {
        guard var trip = trips[tripId] else { throw BookingError.tripNotFound }
        await MockLatency.short()

        let latestDriverOffer = trip.offers.last { $0.author == .driver }?.amount ?? trip.suggestedFare
        trip.agreedFare = latestDriverOffer
        trip.driver = await matchDriver(vehicleType: trip.vehicleType, womenSafeModeRequested: trip.womenSafeModeRequested)
        trip.status = .driverAssigned
        trip.driverAssignedAt = Date()
        trips[tripId] = trip
        return trip
    }

    public func incomingRequestsForDriver() async throws -> [Trip] {
        await MockLatency.short()
        let sample = Array(dhakaLocations.shuffled().prefix(4))
        let requestCount = Int.random(in: 1...2)

        let requests = (0..<requestCount).map { index in
            let pickup = sample[index * 2]
            let dropoff = sample[index * 2 + 1]
            let vehicleType = VehicleType.allCases.randomElement() ?? .car
            let distanceKm = pickup.point.distance(to: dropoff.point) / 1000
            let fare = vehicleType.baseFare + (vehicleType.baseFarePerKm * distanceKm)
            return Trip(
                status: .negotiating,
                vehicleType: vehicleType,
                pickup: pickup,
                dropoff: dropoff,
                suggestedFare: fare,
                offers: [FareOffer(author: .rider, amount: fare, createdAt: Date())],
                riderId: UUID().uuidString,
                riderName: riderNamePool.randomElement() ?? riderNamePool[0]
            )
        }

        for request in requests {
            trips[request.id] = request
        }
        return requests
    }

    public func cancelNegotiation(tripId: String, reason: String, fee: Money) async throws {
        guard var trip = trips[tripId] else { throw BookingError.tripNotFound }
        trip.status = .cancelled
        trips.removeValue(forKey: tripId)
    }

    public func setDriverPreferences(favoriteDriverIds: Set<String>, blockedDriverIds: Set<String>) async {
        self.favoriteDriverIds = favoriteDriverIds
        self.blockedDriverIds = blockedDriverIds
    }

    /// Women Safe Mode: usually a female driver, sometimes (after a delay) any driver, which
    /// is what makes the "fallback driver" notice reachable. Blocked drivers are always excluded.
    private func matchDriver(vehicleType: VehicleType, womenSafeModeRequested: Bool) async -> TripDriverInfo {
        let eligiblePool = driverPool.filter { !blockedDriverIds.contains($0.id) }

        guard womenSafeModeRequested else {
            return makeMockDriver(vehicleType: vehicleType, from: eligiblePool)
        }

        let femaleDrivers = eligiblePool.filter { $0.gender == .female }
        if Double.random(in: 0...1) < 0.7 {
            return makeMockDriver(vehicleType: vehicleType, from: femaleDrivers)
        }

        await MockLatency.short()
        return makeMockDriver(vehicleType: vehicleType, from: eligiblePool)
    }

    /// Favorites in the pool win most of the time; otherwise any driver in the pool.
    private func makeMockDriver(vehicleType: VehicleType, from pool: [DriverProfile]) -> TripDriverInfo {
        let favoritesInPool = pool.filter { favoriteDriverIds.contains($0.id) }
        let candidate: DriverProfile
        if !favoritesInPool.isEmpty, Double.random(in: 0...1) < 0.8 {
            candidate = favoritesInPool.randomElement() ?? favoritesInPool[0]
        } else {
            candidate = pool.randomElement() ?? driverPool[0]
        }
        return TripDriverInfo(
            driverId: candidate.id,
            name: candidate.name,
            ratingAverage: Double.random(in: 4.2...5.0),
            vehicleType: vehicleType,
            vehiclePlate: "DHAKA-\(Int.random(in: 1000...9999))",
            etaMinutes: Int.random(in: 2...9),
            currentLocation: dhakaLocations.randomElement()?.point ?? GeoPoint(latitude: 23.78, longitude: 90.41),
            gender: candidate.gender
        )
    }
}
