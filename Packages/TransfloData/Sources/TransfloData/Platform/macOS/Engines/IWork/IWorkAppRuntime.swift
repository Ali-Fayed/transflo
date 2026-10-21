#if os(macOS)
import AppKit
import TransfloDomain

/// Starts and stops iWork apps. Apple Events alone don't reliably launch Pages, Keynote or
/// Numbers (`osascript` reports -600, "Application isn't running"), so they are opened through
/// Launch Services first.
protocol IWorkAppRuntime: Sendable {
    func isRunning(_ app: IWorkApp) -> Bool
    /// Opens the app hidden and without taking focus, returning once it accepts Apple Events.
    func launch(_ app: IWorkApp) async throws(JobError)
    func quit(_ app: IWorkApp)
}

/// `IWorkAppRuntime` backed by `NSWorkspace`.
struct WorkspaceIWorkAppRuntime: IWorkAppRuntime {
    /// How long a cold launch may take before the conversion fails.
    var launchTimeout: Duration = .seconds(30)

    func isRunning(_ app: IWorkApp) -> Bool {
        running(app)?.isFinishedLaunching == true
    }

    func launch(_ app: IWorkApp) async throws(JobError) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.rawValue) else {
            throw .unsupported
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.hides = true
        configuration.addsToRecentItems = false
        do {
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        } catch {
            throw .failed
        }
        let deadline = ContinuousClock.now + launchTimeout
        while !isRunning(app) {
            guard ContinuousClock.now < deadline else { throw .failed }
            do { try await Task.sleep(for: .milliseconds(100)) } catch { throw .cancelled }
        }
    }

    func quit(_ app: IWorkApp) {
        running(app)?.terminate()
    }

    private func running(_ app: IWorkApp) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: app.rawValue).first
    }
}
#endif
