import TransfloDomain

/// What a key press does while the keyboard-driven wheel is open.
enum WheelKeyCommand: Equatable {
    /// Arrow keys: move the highlight one wedge, clockwise or not as seen on screen.
    case step(clockwise: Bool)
    /// Return or Enter: apply the highlighted option (on More, turn the page).
    case confirm
    /// Escape.
    case cancel
    /// A modifier was tapped: switch to the wheel bound to it.
    case modifier(ModifierKey)
}
