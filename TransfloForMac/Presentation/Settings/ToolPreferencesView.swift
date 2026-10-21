import SwiftUI

/// Instant compression preferences stay out of the per-drop path.
struct ToolPreferencesView: View {
    let model: ToolPreferencesViewModel

    var body: some View {
        SettingsSection(title: .settingsCompression) {
            AppChipGroup(key: .settingsCompression, selection: choice, options: Self.options)
            SettingsFootnote(message: description)
        }
    }

    private var description: L10nKey {
        switch model.choice {
        case .light: .compressionLightHint
        case .medium: .compressionMediumHint
        case .strong: .compressionStrongHint
        }
    }

    private var choice: Binding<CompressionChoice> {
        Binding(get: { model.choice }, set: { model.select($0) })
    }

    private static let options: [AppSegmentedPicker<CompressionChoice>.Option] = [
        .init(value: .light, label: .settingsQualityBest), .init(value: .medium, label: .compressionMedium),
        .init(value: .strong, label: .settingsQualitySmaller)
    ]
}
