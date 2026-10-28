import Foundation

/// Topic the user picks when contacting support.
public enum SupportRequestCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case lostItem
    case tripIssue
    case paymentIssue
    case appProblem
    case other

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .lostItem: return String(localized: "Lost item")
        case .tripIssue: return String(localized: "Trip issue")
        case .paymentIssue: return String(localized: "Payment issue")
        case .appProblem: return String(localized: "App problem")
        case .other: return String(localized: "Other")
        }
    }
}

/// A support request the user submitted, kept in `SupportRequestStore`.
public struct SupportRequest: Identifiable, Codable, Sendable {
    public let id: String
    public let category: SupportRequestCategory
    public let message: String
    public let submittedAt: Date

    public init(id: String = UUID().uuidString, category: SupportRequestCategory, message: String, submittedAt: Date = Date()) {
        self.id = id
        self.category = category
        self.message = message
        self.submittedAt = submittedAt
    }
}

#if DEBUG

// Fixed fake data for SwiftUI previews. Debug builds only, so none of it ships.

public extension SupportRequest {
    static func mock(category: SupportRequestCategory = .tripIssue, message: String = "The driver took a longer route than expected.") -> SupportRequest {
        SupportRequest(id: "request-1", category: category, message: message, submittedAt: Date().addingTimeInterval(-3600))
    }

    static func mockList() -> [SupportRequest] {
        [
            SupportRequest(id: "request-1", category: .tripIssue, message: "The driver took a longer route than expected.", submittedAt: Date().addingTimeInterval(-3600)),
            SupportRequest(id: "request-2", category: .lostItem, message: "I left a black umbrella in the car.", submittedAt: Date().addingTimeInterval(-86_400)),
            SupportRequest(id: "request-3", category: .paymentIssue, message: "I was charged twice for my last ride.", submittedAt: Date().addingTimeInterval(-259_200))
        ]
    }
}

#endif
