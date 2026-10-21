import AppKit

/// Borderless, transparent, non-activating panel that floats above every app and Space,
/// so Transflo's wheel and HUD can appear over Finder without stealing focus.
final class FloatingPanel: NSPanel {
    init(size: CGSize, identifier: String) {
        super.init(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        level = .popUpMenu
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        self.identifier = NSUserInterfaceItemIdentifier(identifier)
    }

    /// Keyboard-driven panels (the wheel opened by the hotkey) take key focus; others never do.
    var allowsKey = false

    override var canBecomeKey: Bool { allowsKey }
    override var canBecomeMain: Bool { false }

    /// Places the panel with its origin at `origin` (screen space), kept inside the visible frame
    /// of the screen containing `anchor`.
    func place(origin: CGPoint, anchor: CGPoint) {
        var origin = origin
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(anchor) }) {
            let visible = screen.visibleFrame
            origin.x = min(max(origin.x, visible.minX), visible.maxX - frame.width)
            origin.y = min(max(origin.y, visible.minY), visible.maxY - frame.height)
        }
        setFrameOrigin(origin)
        orderFrontRegardless()
    }
}
