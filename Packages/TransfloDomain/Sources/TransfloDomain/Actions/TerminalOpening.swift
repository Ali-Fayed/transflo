import Foundation

/// Opens folders in a terminal app.
public protocol TerminalOpening: Sendable {
    /// Terminal apps installed on this Mac, in `TerminalApp` order.
    func installedApps() -> [TerminalApp]
    func open(_ folders: [URL], with app: TerminalApp) async throws(JobError)
}
