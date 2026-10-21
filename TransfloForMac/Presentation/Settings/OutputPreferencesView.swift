import SwiftUI
import TransfloDomain

/// Shows naming choices with concrete examples, using the existing settings components.
struct OutputPreferencesView: View {
    let model: ToolPreferencesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.xLarge) {
            ToolPreferencesView(model: model)
            naming
        }
    }

    private var naming: some View {
        SettingsSection(title: .settingsNameStyle) {
            AppSegmentedPicker(key: .settingsNameStyle,
                               selection: Binding(get: { model.nameStyle }, set: { model.selectNameStyle($0) }),
                               options: Self.styles)
            SettingsFootnote(message: model.nameStyle == .parentheses ? .nameStyleParenthesesHint : .nameStyleWordHint)
        }
    }

    private static let styles: [AppSegmentedPicker<ToolNameStyle>.Option] = [
        .init(value: .parentheses, label: .nameStyleParentheses), .init(value: .word, label: .nameStyleWord)
    ]
}
