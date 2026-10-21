import SwiftUI

/// Up and down buttons for reordering a list row from the keyboard or with VoiceOver.
struct AppMoveButtons: View {
    let canMoveUp: Bool
    let canMoveDown: Bool
    /// Called with -1 to move up and 1 to move down.
    let move: (Int) -> Void

    var body: some View {
        AppIconButton(symbol: .arrowUp, label: .editorMovePageUp) { move(-1) }
            .disabled(!canMoveUp)
        AppIconButton(symbol: .arrowDown, label: .editorMovePageDown) { move(1) }
            .disabled(!canMoveDown)
    }
}
