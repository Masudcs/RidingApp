import SwiftUI

/// Live support chat. Listens for messages only while visible.
public struct SupportChatScreen: View {
    @State private var viewModel: SupportChatViewModel

    public init(viewModel: SupportChatViewModel? = nil) {
        _viewModel = State(wrappedValue: viewModel ?? SupportChatViewModel())
    }

    public var body: some View {
        @Bindable var viewModel = viewModel
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.messages) { message in
                            SupportChatBubbleView(text: message.text, sentAt: message.sentAt, isMine: !message.isFromSupport)
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
        .navigationTitle("Live Support")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.didAppear()
        }
        .onDisappear {
            viewModel.didDisappear()
        }
    }
}

#if DEBUG

#Preview("Data") {
    NavigationStack {
        SupportChatScreen(viewModel: SupportChatViewModel(isPreview: true))
    }
}

#Preview("Empty") {
    NavigationStack {
        SupportChatScreen(viewModel: SupportChatViewModel(isPreview: true, isEmptyView: true))
    }
}

#Preview("Error") {
    NavigationStack {
        SupportChatScreen(viewModel: SupportChatViewModel(isPreview: true, isError: true))
    }
}

#Preview("Data - Dark") {
    NavigationStack {
        SupportChatScreen(viewModel: SupportChatViewModel(isPreview: true))
    }
    .preferredColorScheme(.dark)
}

#endif
