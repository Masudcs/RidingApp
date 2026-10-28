import SwiftUI

/// Settings form for Silent SOS (on/off and the spoken codeword).
public struct SilentSOSSettingsScreen: View {
    @State private var viewModel: SilentSOSSettingsViewModel

    public init() {
        _viewModel = State(wrappedValue: SilentSOSSettingsViewModel())
    }

    #if DEBUG
    /// Preview-only: shows a ready-made view model (the view model type is not public).
    init(previewViewModel: SilentSOSSettingsViewModel) {
        _viewModel = State(wrappedValue: previewViewModel)
    }
    #endif

    public var body: some View {
        @Bindable var viewModel = viewModel
        Form {
            Section {
                Text("Silently trigger SOS by saying a codeword — audio is processed entirely on your device and never leaves it, even during an active trip.")
                    .font(BrandTypography.body)
                    .foregroundStyle(BrandColor.textSecondary)
            }

            Section("Silent SOS") {
                Toggle("Enable Silent SOS", isOn: $viewModel.isEnabled)

                TextField("Codeword", text: $viewModel.codeword)
                    .autocorrectionDisabled()
                    .disabled(!viewModel.isEnabled)
            }

            Section {
                Text("When enabled, Silent SOS only listens while a trip is active. Saying the codeword during a trip triggers an emergency alert without needing to touch your screen.")
                    .font(BrandTypography.caption)
                    .foregroundStyle(BrandColor.textSecondary)
            }
        }
        .navigationTitle("Silent SOS")
    }
}

#if DEBUG

#Preview("Enabled") {
    NavigationStack {
        SilentSOSSettingsScreen(previewViewModel: SilentSOSSettingsViewModel(isPreview: true))
    }
}

#Preview("Disabled") {
    NavigationStack {
        SilentSOSSettingsScreen(previewViewModel: SilentSOSSettingsViewModel(isPreview: true, isEmptyView: true))
    }
}

#Preview("Enabled - Dark") {
    NavigationStack {
        SilentSOSSettingsScreen(previewViewModel: SilentSOSSettingsViewModel(isPreview: true))
    }
    .preferredColorScheme(.dark)
}

#endif
