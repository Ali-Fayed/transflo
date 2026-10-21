#if DEBUG
import AppKit
import SwiftUI

/// A full-screen, click-through wallpaper just below Transflo's floating panels (wheel, HUD, shelf) and
/// above every app window, showing `AppScreenshotBackdrop`. Opened only by `-TransfloScreenshotBackdrop`
/// for README shots of the panels; window shots don't use it (it would cover them).
enum ScreenshotBackdropWindow {
    static func make() -> NSWindow? {
        guard let screen = NSScreen.main else { return nil }
        let window = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = NSHostingView(rootView: AppScreenshotBackdrop())
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = true
        window.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue - 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.setFrame(screen.frame, display: true)
        window.orderFront(nil)
        return window
    }
}
#endif
