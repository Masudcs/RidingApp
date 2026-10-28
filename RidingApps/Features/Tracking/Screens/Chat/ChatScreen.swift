import SwiftUI

/// Chat thread for one trip, shown as a sheet from `TripTrackingScreen`. Auto-scrolls to the newest message.
public struct ChatScreen: View {
    @State private var viewModel: ChatViewModel

    public init(tripId: String, currentUserId: String, currentUserRole: UserRole, viewModel: ChatViewModel? = nil) {
        _viewModel = State(wrappedValue: viewModel ?? ChatViewModel(
            tripId: tripId,
            currentUserId: currentUserId,
            currentUserRole: currentUserRole
        ))
    }

    public var body: some View {
        @Bindable var viewModel = viewModel
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.messages) { message in
                            ChatBubbleView(message: message, isMine: viewModel.isMine(message))
                                .id(message.id)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: viewModel.messages.count) { _ in
                    guard let lastId = viewModel.messages.last?.id else { return }
                    withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                }
            }

            if let connectionBannerText = viewModel.connectionBannerText {
                ErrorBanner(connectionBannerText)
                    .padding(.horizontal, 16)
            }

            if let errorMessage = viewModel.errorMessage {
                ErrorBanner(errorMessage)
                    .padding(.horizontal, 16)
            }

            HStack(spacing: 8) {
                TextField("Message", text: $viewModel.draftText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button {
                    viewModel.didTapSend()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundStyle(BrandColor.primary)
                }
                .disabled(!viewModel.canSend)
                .accessibilityLabel("Send message")
            }
            .padding(16)
        }
        .background(BrandColor.background)
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }
}

#if DEBUG

@MainActor
private func previewChatScreen(_ viewModel: ChatViewModel) -> some View {
    NavigationStack {
        ChatScreen(tripId: "trip-1", currentUserId: "rider-1", currentUserRole: .rider, viewModel: viewModel)
    }
}

#Preview("Messages") {
    previewChatScreen(ChatViewModel())
}

#Preview("Empty") {
    previewChatScreen(ChatViewModel(isEmptyView: true))
}

#Preview("Send error") {
    previewChatScreen(ChatViewModel(isError: true))
}

#Preview("Connection problem") {
    previewChatScreen(ChatViewModel(hasConnectionProblem: true))
}

#Preview("Long text") {
    previewChatScreen(ChatViewModel(hasLongText: true))
}

#endif
