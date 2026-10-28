import Foundation

/// A trip-count quest offering a bonus once the driver hits a target. Status only moves forward:
/// inProgress -> completed -> claimed. The server decides when it becomes `completed`; the app
/// only asks to claim it.
public struct DriverIncentive: Identifiable, Equatable, Codable, Sendable {
    /// Progress of the quest; only moves forward.
    public enum Status: String, Codable, Equatable, Sendable {
        case inProgress
        case completed
        case claimed
    }

    public let id: String
    public let title: String
    public let description: String
    public let targetTrips: Int
    public let currentTrips: Int
    public let reward: Money
    public var status: Status

    public init(
        id: String = UUID().uuidString,
        title: String,
        description: String,
        targetTrips: Int,
        currentTrips: Int,
        reward: Money,
        status: Status
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.targetTrips = targetTrips
        self.currentTrips = currentTrips
        self.reward = reward
        self.status = status
    }

    /// 0...1 for the progress bar. Display only; eligibility comes from `status`, not this value.
    public var progress: Double {
        guard targetTrips > 0 else { return 0 }
        return min(1, Double(currentTrips) / Double(targetTrips))
    }
}

/// Reasons the server refuses to claim an incentive.
public enum IncentiveError: Error, Sendable, Equatable {
    case notFound
    case notEligible
}

#if DEBUG

public extension DriverIncentive {
    static func mock(
        id: String = "incentive-1",
        title: String = "Complete 10 trips",
        description: String = "Finish 10 trips today for a bonus.",
        targetTrips: Int = 10,
        currentTrips: Int = 6,
        rewardTaka: Double = 150,
        status: Status = .inProgress
    ) -> DriverIncentive {
        DriverIncentive(
            id: id,
            title: title,
            description: description,
            targetTrips: targetTrips,
            currentTrips: currentTrips,
            reward: .bdt(rewardTaka),
            status: status
        )
    }

    /// One incentive per status.
    static func mockList() -> [DriverIncentive] {
        [
            .mock(id: "incentive-1", currentTrips: 6, status: .inProgress),
            .mock(id: "incentive-2", title: "Weekend warrior", description: "Complete 20 trips this weekend.", targetTrips: 20, currentTrips: 20, rewardTaka: 400, status: .completed),
            .mock(id: "incentive-3", title: "Early bird", description: "Complete 5 trips before 9 AM.", targetTrips: 5, currentTrips: 5, rewardTaka: 100, status: .claimed)
        ]
    }
}

#endif
