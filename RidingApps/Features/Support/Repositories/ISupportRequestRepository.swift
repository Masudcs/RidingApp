import Foundation

/// Sends "contact support" requests to the support team. Real backend: `SupportRequestRepository`;
/// mock mode: `MockSupportRequestRepository`.
public protocol ISupportRequestRepository: Sendable {
    /// Throws `SupportRequestError.emptyMessage` for blank text; other errors come from the backend.
    func submitSupportRequest(category: SupportRequestCategory, message: String) async throws -> SupportRequest
}

/// Reasons a support request is rejected before it is sent.
public enum SupportRequestError: Error, Equatable, Sendable {
    case emptyMessage
}
