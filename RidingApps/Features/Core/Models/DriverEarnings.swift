import Foundation

/// Lifecycle of a cash-out: starts `.processing`, ends `.settled` or `.failed`.
public enum CashOutStatus: String, Codable, Sendable {
    case processing
    case settled
    case failed
}

/// A driver-initiated T+0 cash-out of available trip earnings to a linked MFS/bank destination.
public struct CashOutRequest: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let amount: Money
    public let destination: PaymentMethodType
    public var status: CashOutStatus
    public let requestedAt: Date
    public var settledAt: Date?

    public init(
        id: String = UUID().uuidString,
        amount: Money,
        destination: PaymentMethodType,
        status: CashOutStatus = .processing,
        requestedAt: Date = Date(),
        settledAt: Date? = nil
    ) {
        self.id = id
        self.amount = amount
        self.destination = destination
        self.status = status
        self.requestedAt = requestedAt
        self.settledAt = settledAt
    }
}

/// Figures for the driver earnings dashboard. `availableBalance` is what can still be cashed out.
public struct DriverEarningsSummary: Equatable, Codable, Sendable {
    public let availableBalance: Money
    public let todayEarnings: Money
    public let weekEarnings: Money
    public let completedTripsToday: Int

    public init(availableBalance: Money, todayEarnings: Money, weekEarnings: Money, completedTripsToday: Int) {
        self.availableBalance = availableBalance
        self.todayEarnings = todayEarnings
        self.weekEarnings = weekEarnings
        self.completedTripsToday = completedTripsToday
    }
}

#if DEBUG

public extension CashOutRequest {
    static func mock(
        id: String = "cashout-1",
        taka: Double = 1_000,
        destination: PaymentMethodType = .bKash,
        status: CashOutStatus = .settled,
        hoursAgo: Double = 2
    ) -> CashOutRequest {
        let requestedAt = Date().addingTimeInterval(-hoursAgo * 3_600)
        return CashOutRequest(
            id: id,
            amount: .bdt(taka),
            destination: destination,
            status: status,
            requestedAt: requestedAt,
            settledAt: status == .settled ? requestedAt.addingTimeInterval(5) : nil
        )
    }

    /// Newest first, one of each status.
    static func mockList() -> [CashOutRequest] {
        [
            .mock(id: "cashout-1", taka: 500, destination: .bKash, status: .processing, hoursAgo: 0.1),
            .mock(id: "cashout-2", taka: 1_200, destination: .nagad, status: .settled, hoursAgo: 26),
            .mock(id: "cashout-3", taka: 300, destination: .rocket, status: .failed, hoursAgo: 72)
        ]
    }
}

public extension DriverEarningsSummary {
    static func mock(
        availableBalance: Double = 2_450,
        todayEarnings: Double = 860,
        weekEarnings: Double = 5_320,
        completedTripsToday: Int = 7
    ) -> DriverEarningsSummary {
        DriverEarningsSummary(
            availableBalance: .bdt(availableBalance),
            todayEarnings: .bdt(todayEarnings),
            weekEarnings: .bdt(weekEarnings),
            completedTripsToday: completedTripsToday
        )
    }
}

#endif
