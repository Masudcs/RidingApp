import Foundation

/// Real API client for demand zones.
public final class DemandRepository: IDemandRepository {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    /// Mock in Dev/Staging so the app keeps working offline; the real backend otherwise.
    public static func makeDefault(environment: AppEnvironment = .current) -> IDemandRepository {
        if environment.usesMockServices {
            return MockDemandRepository()
        }
        return DemandRepository(client: APIClientFactory.make(baseURL: environment.apiBaseURL))
    }

    /// Current busy areas for drivers. Any error is passed up for the view model to show.
    public func fetchDemandZones() async throws -> [DemandZone] {
        try await client.send(Endpoint(path: "driver/demand-zones"))
    }
}
