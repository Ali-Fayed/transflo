import SwiftUI

/// A borderless symbol button; `label` names it for VoiceOver and the hover tooltip.
struct AppIconButton: View {
    @Environment(Localizer.self) private var localizer
    let symbol: AppSymbol
    let label: AppTextContent
    let action: () -> Void

    init(symbol: AppSymbol, label: L10nKey, action: @escaping () -> Void) {
        self.init(symbol: symbol, content: .key(label), action: { AppFeedback.selection(); action() })
    }

    /// A button whose name needs arguments, such as "Reset Exposure".
    init(symbol: AppSymbol, content: AppTextContent, action: @escaping () -> Void) {
        self.symbol = symbol
        self.label = content
        self.action = action
    }

    var body: some View {
        Button { AppFeedback.selection(); action() } label: {
            AppIcon(symbol: symbol)
        }
        .buttonStyle(.borderless)
        .appFocusRing(Circle())
        .help(title)
        .accessibilityLabel(title)
    }

    private var title: String {
        switch label {
        case .key(let key): localizer.string(key)
        case let .formatted(key, arguments): localizer.string(key, arguments: arguments)
        case .verbatim(let text): text
        }
    }
}
