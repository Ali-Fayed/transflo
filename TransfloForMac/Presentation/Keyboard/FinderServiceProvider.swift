import AppKit

/// Answers the "Open in Transflo" Service (Finder's right-click › Quick Actions / Services menu).
/// The selector name must match `NSMessage` in Info.plist.
final class FinderServiceProvider: NSObject {
    private let launcher: KeyboardLaunchCoordinator

    init(launcher: KeyboardLaunchCoordinator) {
        self.launcher = launcher
    }

    @objc func openInTransflo(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] ?? []
        launcher.open(urls)
    }
}
