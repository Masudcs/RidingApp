import Observation
import Foundation

/// State for `ChatScreen`: the message list, the draft and send errors.
///
/// Messages arrive only through the repository stream (including the ones we send ourselves), so
/// the list always matches what the server holds.
@MainActor
@Observable
public final class ChatViewModel {
    /// Oldest first, no duplicates.
    public private(set) var messages: [ChatMessage] = []
    public var draftText: String = ""
    /// Set when a send fails; cleared on the next send.
    public var errorMessage: String?
    /// True after repeated poll failures; cleared when polling recovers.
    public private(set) var isConnectionProblem = false

    /// Text for the small connection banner, or nil while the connection is fine.
    public var connectionBannerText: String? {
        isConnectionProblem ? String(localized: "Connection problem. Retrying...") : nil
    }

    private let currentUserRole: UserRole

    private let tripId: String
    private let currentUserId: String
    @ObservationIgnored private let repository: IChatRepository
    @ObservationIgnored private let logger = AppLogger(category: "Chat")
    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var connectionTask: Task<Void, Never>?
    #if DEBUG
    /// Set by the preview initializer so streams and sends never run behind a preview.
    @ObservationIgnored private var isPreview = false
    #endif

    public init(
        tripId: String,
        currentUserId: String,
        currentUserRole: UserRole,
        repository: IChatRepository = AppEnvironment.current.usesMockServices ? MockChatRepository() : ChatRepository()
    ) {
        self.tripId = tripId
        self.currentUserId = currentUserId
        self.currentUserRole = currentUserRole
        self.repository = repository
    }

    public var title: String {
        currentUserRole == .rider ? String(localized: "Chat with driver") : String(localized: "Chat with rider")
    }

    public var canSend: Bool {
        !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func isMine(_ message: ChatMessage) -> Bool {
        message.senderRole == currentUserRole
    }

    /// Starts listening for messages. Safe to call again: the old stream is replaced, and replayed
    /// messages are ignored by `receive` so nothing shows up twice.
    public func onAppear() {
        #if DEBUG
        guard !isPreview else { return }
        #endif
        streamTask?.cancel()
        connectionTask?.cancel()
        streamTask = Task { [weak self, tripId, repository] in
            guard let self else { return }
            for await message in await repository.messageStream(tripId: tripId) {
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

    /// Stops the stream so polling/subscription does not continue after the screen is gone.
    public func onDisappear() {
        #if DEBUG
        guard !isPreview else { return }
        #endif
        streamTask?.cancel()
        connectionTask?.cancel()
        isConnectionProblem = false
    }

    /// Clears the field right away for a snappy feel; if the send fails the text is put back
    /// (unless the user already started typing something new) so it isn't lost.
    public func didTapSend() {
        #if DEBUG
        guard !isPreview else { return }
        #endif
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draftText = ""
        errorMessage = nil

        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await repository.sendMessage(tripId: tripId, senderId: currentUserId, senderRole: currentUserRole, text: text)
            } catch {
                logger.error("Failed to send message: \(error)")
                errorMessage = String(localized: "Couldn't send that message. Please try again.")
                if draftText.isEmpty { draftText = text }
            }
        }
    }

    private func setConnectionProblem(_ hasProblem: Bool) {
        isConnectionProblem = hasProblem
    }

    private func receive(_ message: ChatMessage) {
        guard !messages.contains(where: { $0.id == message.id }) else { return }
        messages.append(message)
        if message.senderRole != currentUserRole {
            let title = message.senderRole == .driver
                ? String(localized: "New message from your driver")
                : String(localized: "New message from your rider")
            LocalNotifications.notify(title: title, body: message.text)
        }
    }
}

#if DEBUG

extension ChatViewModel {
    /// Fixed fake state for previews; the stream, connection polling and sending are disabled.
    convenience init(
        isPreview: Bool = true,
        isError: Bool = false,
        isEmptyView: Bool = false,
        hasConnectionProblem: Bool = false,
        hasLongText: Bool = false
    ) {
        self.init(tripId: "trip-1", currentUserId: "rider-1", currentUserRole: .rider, repository: MockChatRepository())
        self.isPreview = isPreview
        if !isEmptyView {
            messages = ChatMessage.mockThread()
        }
        if hasLongText {
            messages.append(.mock(id: "message-long", senderRole: .driver, text: ChatMessage.mockLongText))
        }
        if isError {
            errorMessage = String(localized: "Couldn't send that message. Please try again.")
            draftText = "Almost there"
        }
        isConnectionProblem = hasConnectionProblem
    }
}

#endif
