import AppKit
import ObjectiveC

/// Keeps an app window on its screen. SwiftUI measures a window's content after the window is created
/// and centered, so the first resize re-centers it at its real size; later resizes (a Settings tab with
/// taller content, an editor's preview arriving) move it back inside the visible area. Small displays,
/// larger-text scaling and 1024 × 768 CI runners otherwise leave controls past the screen edge.
@MainActor
final class WindowPlacement: NSObject {
    private weak var window: NSWindow?
    private var hasMeasuredContent = false
    private static var key = 0

    /// Attaches a placement to `window` for the window's lifetime.
    static func keepOnScreen(_ window: NSWindow) {
        let placement = WindowPlacement(window: window)
        objc_setAssociatedObject(window, &key, placement, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private init(window: NSWindow) {
        self.window = window
        super.init()
        // Selector-based observation unregisters itself when the placement is deallocated.
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidResize),
                                               name: NSWindow.didResizeNotification, object: window)
    }

    @objc private func windowDidResize(_ notification: Notification) {
        place()
    }

    private func place() {
        guard let window, let visible = (window.screen ?? NSScreen.main)?.visibleFrame else { return }
        let target = hasMeasuredContent
            ? Self.fitted(window.frame, in: visible)
            : Self.centered(window.frame.size, in: visible)
        hasMeasuredContent = true
        if target != window.frame { window.setFrame(target, display: true) }
    }

    /// `frame` moved the least distance that puts it inside `visible`, and shrunk only if it is larger.
    nonisolated static func fitted(_ frame: CGRect, in visible: CGRect) -> CGRect {
        let size = CGSize(width: min(frame.width, visible.width), height: min(frame.height, visible.height))
        let x = min(max(frame.minX, visible.minX), visible.maxX - size.width)
        let y = min(max(frame.minY, visible.minY), visible.maxY - size.height)
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }

    /// A frame of `size` centered in `visible`, fitted to it.
    nonisolated static func centered(_ size: CGSize, in visible: CGRect) -> CGRect {
        fitted(CGRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2,
                      width: size.width, height: size.height), in: visible)
    }
}
