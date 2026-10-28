import SwiftUI

/// Help & Support: link to live chat, FAQ, a contact form and the user's past requests.
public struct SupportCenterScreen: View {
    @State private var viewModel: SupportCenterViewModel
    private let rideHistoryStore: RideHistoryStore
    private let userId: String

    public init(userId: String, rideHistoryStore: RideHistoryStore, viewModel: SupportCenterViewModel? = nil) {
        self.userId = userId
        self.rideHistoryStore = rideHistoryStore
        _viewModel = State(wrappedValue: viewModel ?? SupportCenterViewModel(userId: userId))
    }

    public var body: some View {
        @Bindable var viewModel = viewModel
        List {
            Section {
                NavigationLink {
                    SupportChatScreen()
                } label: {
                    Label("Chat with Support", systemImage: "bubble.left.and.bubble.right.fill")
                }
            }

            Section("Frequently Asked Questions") {
                ForEach(viewModel.faqItems) { item in
                    FAQRow(question: item.question, answer: item.answer)
                }
            }

            Section("Contact Support") {
                Picker("Category", selection: $viewModel.category) {
                    ForEach(SupportRequestCategory.allCases) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                if viewModel.showsTripPicker {
                    Picker("Which ride?", selection: $viewModel.selectedTripId) {
                        Text("Not sure").tag(String?.none)
                        ForEach(viewModel.recentTrips) { trip in
                            Text(viewModel.tripLabel(for: trip))
                                .tag(String?.some(trip.tripId))
                        }
                    }
                }
                TextField("Describe the issue", text: $viewModel.message, axis: .vertical)
                    .lineLimit(3...6)
                SecondaryButton(viewModel.isSubmitting ? String(localized: "Sending...") : String(localized: "Submit")) {
                    viewModel.didTapSubmit()
                }
                .disabled(!viewModel.canSubmit)
                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(errorMessage)
                }
                if viewModel.didSubmit {
                    Text("Thanks — we've logged your request.")
                        .font(BrandTypography.caption)
                        .foregroundStyle(BrandColor.success)
                }
            }

            if !viewModel.requests.isEmpty {
                Section("Your Requests") {
                    ForEach(viewModel.requests) { request in
                        SupportRequestRow(
                            categoryName: request.category.displayName,
                            message: request.message,
                            submittedAt: request.submittedAt
                        )
                    }
                }
            }
        }
        .navigationTitle("Help & Support")
        .onAppear {
            viewModel.didUpdateHistory(rideHistoryStore.history(forUserId: userId))
        }
        .onChange(of: rideHistoryStore.entries) {
            viewModel.didUpdateHistory(rideHistoryStore.history(forUserId: userId))
        }
    }
}

#if DEBUG

/// Empty ride-history store backed by a private suite, so previews never read or write real history.
@MainActor
private func previewRideHistoryStore() -> RideHistoryStore {
    RideHistoryStore(defaults: UserDefaults(suiteName: "preview.supportRideHistory")!)
}

#Preview("Data") {
    NavigationStack {
        SupportCenterScreen(userId: "preview-user", rideHistoryStore: previewRideHistoryStore(), viewModel: SupportCenterViewModel())
    }
}

#Preview("Empty") {
    NavigationStack {
        SupportCenterScreen(userId: "preview-user", rideHistoryStore: previewRideHistoryStore(), viewModel: SupportCenterViewModel(isEmptyView: true))
    }
}

#Preview("Submitting") {
    NavigationStack {
        SupportCenterScreen(userId: "preview-user", rideHistoryStore: previewRideHistoryStore(), viewModel: SupportCenterViewModel(isLoading: true))
    }
}

#Preview("Submitted") {
    NavigationStack {
        SupportCenterScreen(userId: "preview-user", rideHistoryStore: previewRideHistoryStore(), viewModel: SupportCenterViewModel(isSubmitted: true))
    }
}

#Preview("Error") {
    NavigationStack {
        SupportCenterScreen(userId: "preview-user", rideHistoryStore: previewRideHistoryStore(), viewModel: SupportCenterViewModel(isError: true))
    }
}

#Preview("Data - Dark") {
    NavigationStack {
        SupportCenterScreen(userId: "preview-user", rideHistoryStore: previewRideHistoryStore(), viewModel: SupportCenterViewModel())
    }
    .preferredColorScheme(.dark)
}

#endif
