import Foundation

/// API-backed support requests: one `POST support/requests` per submission.
public final class SupportRequestRepository: ISupportRequestRepository {
    /// Endpoint paths, relative to the API base URL.
    private enum Paths {
        static let requests = "support/requests"
    }

    /// Body for `POST support/requests`.
    private struct SubmitBody: Encodable {
        let category: SupportRequestCategory
        let message: String
    }

    /// Only the id is needed from the server's reply.
    private struct SubmitResponse: Decodable {
        let id: String
    }

    private let apiClient: APIClient

    public init(apiClient: APIClient = APIClientFactory.make()) {
        self.apiClient = apiClient
    }

    /// Trims the text and rejects blank messages before any request is made.
    public func submitSupportRequest(category: SupportRequestCategory, message: String) async throws -> SupportRequest {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SupportRequestError.emptyMessage }

        let body = try JSONEncoder().encode(SubmitBody(category: category, message: trimmed))
        let response: SubmitResponse = try await apiClient.send(Endpoint(path: Paths.requests, method: .post, body: body))
        return SupportRequest(id: response.id, category: category, message: trimmed)
    }
}
