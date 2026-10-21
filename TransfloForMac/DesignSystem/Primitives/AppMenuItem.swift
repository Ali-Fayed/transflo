import SwiftUI

/// A localized item for the menu-bar menu.
struct AppMenuItem: View {
    @Environment(Localizer.self) private var localizer
    let key: L10nKey
    var shortcut: KeyEquivalent?
    let action: () -> Void

    var body: some View {
        if let shortcut {
            item.keyboardShortcut(shortcut, modifiers: .command)
        } else {
            item
        }
    }

    private var item: some View {
        Button(localizer.string(key), action: action)
    }
}
