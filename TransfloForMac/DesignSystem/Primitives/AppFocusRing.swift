import SwiftUI

/// Keyboard focus in the user's accent color. macOS draws its own focus ring in the system accent,
/// which clashes with the accent chosen in Settings, so controls hide it and draw this ring instead.
struct AppFocusRing<RingShape: InsettableShape>: ViewModifier {
    let shape: RingShape
    /// Also makes the view take focus when clicked (for controls that aren't focusable by default).
    let makesFocusable: Bool
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        focusable(content)
            .focused($isFocused)
            .focusEffectDisabled()
            .overlay {
                shape.inset(by: -AppDimensions.Stroke.focusGap)
                    .strokeBorder(AppColors.accent, lineWidth: AppDimensions.Stroke.focus)
                    .opacity(isFocused ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .animation(AppAnimations.standard, value: isFocused)
    }

    @ViewBuilder private func focusable(_ content: Content) -> some View {
        if makesFocusable { content.focusable() } else { content }
    }
}

extension View {
    /// Draws keyboard focus as a ring in the chosen accent, just outside `shape`.
    func appFocusRing<RingShape: InsettableShape>(_ shape: RingShape, focusable: Bool = false) -> some View {
        modifier(AppFocusRing(shape: shape, makesFocusable: focusable))
    }
}
