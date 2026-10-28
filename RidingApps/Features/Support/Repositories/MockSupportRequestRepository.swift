import Foundation

/// Keeps submitted requests in memory after a short fake delay.
public actor MockSupportRequestRepository: ISupportRequestRepository {
    /// Everything submitted so far, oldest first.
    public private(set) var submitted: [SupportRequest] = []

    public init() {}

    public func submitSupportRequest(category: SupportRequestCategory, message: String) async throws -> SupportRequest {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SupportRequestError.emptyMessage }

        await MockLatency.short()

        let request = SupportRequest(category: category, message: trimmed)
        submitted.append(request)
        return request
    }
}
