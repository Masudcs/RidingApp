import SwiftUI

/// Menu of safety settings shown in the Safety tab. Add a `Destination` case here and a matching
/// screen in `SafetyTabScreen` to add an entry.
@MainActor
@Observable
final class SafetyTabViewModel {
    /// A screen reachable from the Safety tab menu.
    enum Destination: CaseIterable, Identifiable {
        case emergencyContacts
        case silentSOS

        var id: Self { self }

        var title: String {
            switch self {
            case .emergencyContacts: return String(localized: "Emergency Contacts")
            case .silentSOS: return String(localized: "Silent SOS Codeword")
            }
        }
    }

    let title = String(localized: "Safety")
    let destinations = Destination.allCases
}
