import SwiftUI

/// App entry point. Opens one window whose root is `RootScreen`, which picks the auth, rider or driver flow.
@main
struct RidingApp: App {
    var body: some Scene {
        WindowGroup {
            RootScreen()
        }
    }
}
