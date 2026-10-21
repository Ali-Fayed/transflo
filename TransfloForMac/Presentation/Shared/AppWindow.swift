import AppKit

/// A titled, closable window whose content runs under a transparent title bar, so the frosted
/// backdrop fills the whole window (Factory for every app window).
enum AppWindow {
    static func make(contentViewController: NSViewController, identifier: String) -> NSWindow {
        let window = NSWindow(contentViewController: contentViewController)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.identifier = NSUserInterfaceItemIdentifier(identifier)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(LaunchArgument.screenshotCapture) {
            window.level = .popUpMenu
        }
        #endif
        window.center()
        WindowPlacement.keepOnScreen(window)
        return window
    }
}
