import SwiftUI

/// Safety tab of the rider app: a list linking to the emergency contacts and Silent SOS settings.
struct SafetyTabScreen: View {
    @State private var viewModel: SafetyTabViewModel

    init(viewModel: SafetyTabViewModel? = nil) {
        _viewModel = State(wrappedValue: viewModel ?? SafetyTabViewModel())
    }

    var body: some View {
        NavigationStack {
            List(viewModel.destinations) { destination in
                NavigationLink(destination.title) {
                    switch destination {
                    case .emergencyContacts: EmergencyContactsScreen()
                    case .silentSOS: SilentSOSSettingsScreen()
                    }
                }
            }
            .navigationTitle(viewModel.title)
        }
    }
}

#if DEBUG

#Preview("Safety tab") {
    SafetyTabScreen()
}

#Preview("Safety tab - Dark") {
    SafetyTabScreen()
        .preferredColorScheme(.dark)
}

#endif
