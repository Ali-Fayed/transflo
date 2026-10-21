import AppKit
import TransfloDomain

/// Opens links with the system's default handler (a browser, or the App Store for `macappstore:`).
public struct WorkspaceURLOpener: URLOpening {
    public init() {}

    public func open(_ url: URL) {
        Task { @MainActor in NSWorkspace.shared.open(url) }
    }
}
