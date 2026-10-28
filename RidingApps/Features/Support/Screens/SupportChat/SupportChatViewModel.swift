import Foundation
import Observation

/// State for the live support chat. Incoming messages (including our own, echoed by the
/// repository) arrive through one stream that runs while the screen is visible.
@MainActor
@Observable
public final class SupportChatViewModel {
    public private(set) var messages: [SupportChatMessage] = []
    public var draftText: String = ""
    public private(set) var errorMessage: String?
    /// True after repeated poll failures; cleared when polling recovers.
    public private(set) var isConnectionProblem = false

    /// Text for the small connection banner, or nil while the connection is fine.
    public var connectionBannerText: String? {
        isConnectionProblem ? String(localized: "Connection problem. Retrying...") : nil
    }

    @ObservationIgnored private let repository: ISupportChatRepository
    @ObservationIgnored private let logger = AppLogger(category: "SupportChat")
    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var connectionTask: Task<Void, Never>?
    /// Set only by the debug preview initializer; stops streaming and sending.
    @ObservationIgnored private var isPreview = false

    public init(
        repository: ISupportChatRepository = AppEnvironment.current.usesMockServices ? MockSupportChatRepository() : SupportChatRepository()
    ) {
        self.repository = repository
    }

    public var canSend: Bool {
        !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Starts listening for messages. The stream replays history each time, so `receive` skips ids already shown.
    public func didAppear() {
        guard !isPreview else { return }
        streamTask?.cancel()
        connectionTask?.cancel()
        streamTask = Task { [weak self, repository] in
            guard let self else { return }
            for await message in await repository.messageStream() {
                await self.receive(message)
            }
        }
        connectionTask = Task { [weak self, repository] in
            for await hasProblem in repository.connectionProblemStream() {
                guard let self else { return }
                await self.setConnectionProblem(hasProblem)
            }
        }
    }

    /// Stops the stream so no polling or tasks outlive the screen.
    public func didDisappear() {
        guard !isPreview else { return }
        streamTask?.cancel()
        connectionTask?.cancel()
        isConnectionProblem = false
    }

    /// Sends the trimmed draft. The draft is cleared right away; if sending fails it is put back
    /// (unless the user already started typing something else) so the text isn't lost.
    public func didTapSend() {
        guard !isPreview else { return }
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draftText = ""
        errorMessage = nil

        Task {
            do {
                _ = try await repository.sendMessage(text: text)
            } catch {
                logger.error("Failed to send support message: \(error)")
                errorMessage = String(localized: "Couldn't send that message. Please try again.")
                if draftText.isEmpty { draftText = text }
            }
        }
    }

    private func setConnectionProblem(_ hasProblem: Bool) {
        isConnectionProblem = hasProblem
    }

    private func receive(_ message: SupportChatMessage) {
        guard !messages.contains(where: { $0.id == message.id }) else { return }
        messages.append(message)
    }
}

#if DEBUG

extension SupportChatViewModel {
    /// Fixed fake state; no stream or repository call ever starts. Loading and empty both show no
    /// messages, error shows the send error and the connection banner. `isPreview` has no default
    /// so a plain `init()` call stays unambiguous.
    convenience init(isPreview: Bool, isLoading: Bool = false, isError: Bool = false, isEmptyView: Bool = false) {
        self.init(repository: MockSupportChatRepository())
        self.isPreview = isPreview
        self.messages = isLoading || isEmptyView ? [] : SupportChatMessage.mockList()
        self.draftText = isLoading ? "" : "Thanks, any update?"
        self.isConnectionProblem = isError
        self.errorMessage = isError ? String(localized: "Couldn't send that message. Please try again.") : nil
    }
}

#endif
