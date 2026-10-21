import SwiftUI

/// The hint plus Undo (⌘Z) and Clear under the annotate and redact boards.
struct MarkupFooter: View {
    let hint: L10nKey
    let canUndo: Bool
    let onUndo: () -> Void
    let onClear: () -> Void
    var canClear: Bool?
    var canRedo = false
    var onRedo: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.small) {
            AppText(hint, style: .caption, color: .secondary)
            HStack {
                AppButton(key: .editorUndo, variant: .tertiary, isEnabled: canUndo,
                          shortcut: KeyboardShortcut("z", modifiers: .command), action: onUndo)
                AppButton(key: .editorRedo, variant: .tertiary, isEnabled: canRedo,
                          shortcut: KeyboardShortcut("z", modifiers: [.command, .shift]), action: onRedo)
                AppButton(key: .editorClear, variant: .tertiary, isEnabled: canClear ?? canUndo, action: onClear)
            }
        }
    }
}
