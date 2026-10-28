/// Source of demand-zone data (real API or mock).
public protocol IDemandRepository: Sendable {
    /// Zones are a snapshot; ids may change on every fetch.
    func fetchDemandZones() async throws -> [DemandZone]
}
