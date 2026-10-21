import AppKit
import TransfloDomain

/// Opens folders in a terminal app through Launch Services, found by bundle identifier.
public struct WorkspaceTerminalOpener: TerminalOpening {
    public init() {}

    public func installedApps() -> [TerminalApp] {
        TerminalApp.allCases.filter { Self.applicationURL(for: $0) != nil }
    }

    public func open(_ folders: [URL], with app: TerminalApp) async throws(JobError) {
        guard let application = Self.applicationURL(for: app) else { throw .unsupported }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        do {
            _ = try await NSWorkspace.shared.open(folders, withApplicationAt: application, configuration: configuration)
        } catch {
            throw .failed
        }
    }

    private static func applicationURL(for app: TerminalApp) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier)
    }
}
