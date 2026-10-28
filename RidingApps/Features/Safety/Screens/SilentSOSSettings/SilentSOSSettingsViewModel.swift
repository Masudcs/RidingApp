import Observation
import Foundation

/// Edits the Silent SOS settings and saves each change straight to `SilentSOSPreferences`.
/// The trip screen reads them when a trip starts, so changes apply from the next trip.
@MainActor
@Observable
final class SilentSOSSettingsViewModel {
    var isEnabled: Bool {
        didSet {
            guard !isPreview else { return }
            SilentSOSPreferences.isEnabled = isEnabled
        }
    }

    var codeword: String {
        didSet {
            guard !isPreview else { return }
            SilentSOSPreferences.codeword = codeword
        }
    }

    /// Set only by the debug preview initializer; keeps fake settings out of `UserDefaults`.
    @ObservationIgnored private var isPreview = false

    init() {
        self.isEnabled = SilentSOSPreferences.isEnabled
        self.codeword = SilentSOSPreferences.codeword
    }
}

#if DEBUG

extension SilentSOSSettingsViewModel {
    /// Fixed fake settings that are never saved. `isEmptyView` means Silent SOS is switched off.
    /// `isPreview` has no default so a plain `init()` call stays unambiguous.
    convenience init(isPreview: Bool, isEmptyView: Bool = false) {
        self.init()
        self.isPreview = isPreview
        self.isEnabled = !isEmptyView
        self.codeword = SilentSOSPreferences.defaultCodeword
    }
}

#endif
