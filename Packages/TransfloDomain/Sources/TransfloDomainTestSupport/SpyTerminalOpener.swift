import Foundation
import TransfloDomain

// @unchecked: all mutable state is guarded by `lock`.
/// Reports a fixed set of installed terminals and records what it opened.
public final class SpyTerminalOpener: TerminalOpening, @unchecked Sendable {
    /// One recorded `open` call.
    public struct Call: Equatable, Sendable {
        public let folders: [URL]
        public let app: TerminalApp
    }

    private let lock = NSLock()
    private let installed: [TerminalApp]
    private var calls: [Call] = []

    public init(installed: [TerminalApp]) {
        self.installed = installed
    }

    public var received: [Call] { lock.withLock { calls } }

    public func installedApps() -> [TerminalApp] {
        installed
    }

    public func open(_ folders: [URL], with app: TerminalApp) async throws(JobError) {
        lock.withLock { calls.append(Call(folders: folders, app: app)) }
    }
}
