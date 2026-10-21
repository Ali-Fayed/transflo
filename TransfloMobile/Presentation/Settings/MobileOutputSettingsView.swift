import SwiftUI
import TransfloDomain

struct MobileOutputSettingsView: View {
    let model: ToolPreferencesViewModel

    var body: some View {
        Form {
            Section {
                AppSegmentedPicker(key: .settingsCompression, selection: Binding(
                    get: { model.choice }, set: { model.select($0) }
                ), options: [
                    .init(value: .light, label: .mobileBest), .init(value: .medium, label: .mobileBalanced),
                    .init(value: .strong, label: .mobileSmaller)
                ])
                AppText(compressionHint, style: .caption, color: .secondary)
            } header: { AppText(.settingsCompression) }
            Section {
                AppSegmentedPicker(key: .settingsNameStyle, selection: Binding(
                    get: { model.nameStyle }, set: { model.selectNameStyle($0) }
                ), options: [
                    .init(value: .parentheses, label: .nameStyleParentheses),
                    .init(value: .word, label: .nameStyleWord)
                ])
                AppText(model.nameStyle == .parentheses ? .nameStyleParenthesesHint : .nameStyleWordHint,
                        style: .caption, color: .secondary)
            } header: { AppText(.settingsNameStyle) }
        }
        .appScreenBackground()
        .mobileNavigationBar(.settingsOutput)
        .accessibilityIdentifier("mobile.outputSettings")
    }

    private var compressionHint: L10nKey {
        switch model.choice {
        case .light: .compressionLightHint
        case .medium: .compressionMediumHint
        case .strong: .compressionStrongHint
        }
    }
}
