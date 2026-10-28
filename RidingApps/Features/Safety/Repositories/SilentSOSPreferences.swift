import Foundation

/// UserDefaults-backed Silent SOS settings. Read by the active-trip screen that actually
/// starts/stops `SilentSOSListener`, and written by the Silent SOS settings screen.
public enum SilentSOSPreferences {
    /// `UserDefaults` keys.
    private enum Keys {
        static let isEnabled = "SilentSOS.isEnabled"
        static let codeword = "SilentSOS.codeword"
    }

    /// Used until the user sets their own.
    public static let defaultCodeword = "help me now"

    /// Whether the active-trip screen should start listening for the codeword.
    public static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.isEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.isEnabled) }
    }

    /// Phrase that triggers Silent SOS. A blank saved value falls back to the default, because an
    /// empty codeword would never match and Silent SOS would look on but do nothing.
    public static var codeword: String {
        get {
            let saved = UserDefaults.standard.string(forKey: Keys.codeword)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return saved.isEmpty ? defaultCodeword : saved
        }
        set { UserDefaults.standard.set(newValue, forKey: Keys.codeword) }
    }
}
