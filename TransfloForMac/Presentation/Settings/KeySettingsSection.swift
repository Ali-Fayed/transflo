import SwiftUI
import TransfloDomain

/// Settings › Keys: the modifier for each wheel, the global shortcut, and the terminal app.
struct KeySettingsSection: View {
    let viewModel: KeySettingsViewModel

    var body: some View {
        SettingsSection(title: .settingsKeysSection) {
            ForEach(Self.wheels, id: \.wheel) { row in
                SettingsRow(label: row.label) {
                    AppSegmentedPicker(key: row.label, selection: binding(for: row.wheel), options: Self.modifiers)
                }
            }
            if viewModel.showsShortcut {
                SettingsDivider()
                SettingsRow(label: .settingsShortcut) {
                    AppShortcutRecorder(text: viewModel.shortcutText, onRecord: viewModel.record)
                }
                SettingsFootnote(message: viewModel.shortcutMessage ?? .settingsShortcutHint,
                                 tone: viewModel.shortcutMessage == nil ? .secondary : .danger)
            }
            if viewModel.installedTerminals.count > 1 {
                SettingsDivider()
                SettingsRow(label: .settingsTerminal) {
                    AppSegmentedPicker(key: .settingsTerminal, selection: terminal, options: terminalOptions)
                }
            }
        }
    }

    private func binding(for wheel: WheelKind) -> Binding<ModifierKey> {
        Binding(get: { viewModel.key(for: wheel) }, set: { viewModel.assign($0, to: wheel) })
    }

    private var terminal: Binding<TerminalApp> {
        Binding(get: { viewModel.preferences.terminal }, set: { viewModel.selectTerminal($0) })
    }

    private var terminalOptions: [AppSegmentedPicker<TerminalApp>.Option] {
        viewModel.installedTerminals.map { .init(value: $0, label: Self.terminalNames[$0] ?? .terminalApple) }
    }

    private static let wheels: [(wheel: WheelKind, label: L10nKey)] = [
        (.convert, .settingsConvertKey), (.tools, .settingsToolsKey), (.actions, .settingsActionsKey)
    ]

    private static let modifiers: [AppSegmentedPicker<ModifierKey>.Option] = [
        .init(value: .shift, label: .modifierShift), .init(value: .command, label: .modifierCommand),
        .init(value: .control, label: .modifierControl), .init(value: .option, label: .modifierOption)
    ]

    private static let terminalNames: [TerminalApp: L10nKey] = [
        .terminal: .terminalApple, .iTerm: .terminalITerm, .ghostty: .terminalGhostty, .warp: .terminalWarp
    ]
}
