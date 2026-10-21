import SwiftUI

/// A localized push button. `primary` uses the accent and answers Return; `secondary` answers Esc;
/// `tertiary` answers only its own `shortcut`.
struct AppButton: View {
    enum Variant {
        case primary
        case secondary
        /// An in-editor action: bordered, with no Return/Esc binding (optionally its own `shortcut`).
        case tertiary
    }

    @Environment(Localizer.self) private var localizer
    let label: AppTextContent
    var variant: Variant = .secondary
    var isEnabled = true
    var shortcut: KeyboardShortcut?
    let action: () -> Void

    init(
        key: L10nKey,
        variant: Variant = .secondary,
        isEnabled: Bool = true,
        shortcut: KeyboardShortcut? = nil,
        action: @escaping () -> Void
    ) {
        self.init(label: .key(key), variant: variant, isEnabled: isEnabled, shortcut: shortcut, action: action)
    }

    /// A button whose title is data rather than copy, such as a preset value ("50 %", "1920 px").
    init(
        label: AppTextContent,
        variant: Variant = .secondary,
        isEnabled: Bool = true,
        shortcut: KeyboardShortcut? = nil,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.variant = variant
        self.isEnabled = isEnabled
        self.shortcut = shortcut
        self.action = action
    }

    private var title: String {
        switch label {
        case .key(let key): localizer.string(key)
        case let .formatted(key, arguments): localizer.string(key, arguments: arguments)
        case .verbatim(let text): text
        }
    }

    var body: some View {
        switch variant {
        case .primary:
            Button(title, action: { AppFeedback.selection(); action() })
                .buttonStyle(.borderedProminent)
                .tint(AppColors.accent)
                .keyboardShortcut(.defaultAction)
                .disabled(!isEnabled)
                .appFocusRing(Capsule())
        case .secondary:
            Button(title, action: { AppFeedback.selection(); action() })
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                .disabled(!isEnabled)
                .appFocusRing(Capsule())
        case .tertiary:
            Button(title, action: { AppFeedback.selection(); action() })
                .buttonStyle(.bordered)
                .keyboardShortcut(shortcut)
                .disabled(!isEnabled)
                .appFocusRing(Capsule())
        }
    }
}
