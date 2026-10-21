#if os(macOS)
import TransfloDomain

/// Keeps an iWork app running while conversions use it. An app Transflo had to open is quit
/// again when its last conversion ends; an app the user already had open is left alone.
actor IWorkAppLauncher {
    static let shared = IWorkAppLauncher(runtime: WorkspaceIWorkAppRuntime())

    private let runtime: any IWorkAppRuntime
    private var users: [IWorkApp: Int] = [:]
    private var opened: Set<IWorkApp> = []

    init(runtime: any IWorkAppRuntime) {
        self.runtime = runtime
    }

    /// Runs `work` with `app` open, opening it first when needed.
    func withApp<Value: Sendable>(
        _ app: IWorkApp,
        _ work: @Sendable () async throws(JobError) -> Value
    ) async throws(JobError) -> Value {
        try await acquire(app)
        defer { release(app) }
        return try await work()
    }

    private func acquire(_ app: IWorkApp) async throws(JobError) {
        users[app, default: 0] += 1
        guard !runtime.isRunning(app) else { return }
        do {
            try await runtime.launch(app)
            opened.insert(app)
        } catch {
            release(app)
            throw error
        }
    }

    private func release(_ app: IWorkApp) {
        let remaining = (users[app] ?? 1) - 1
        users[app] = remaining > 0 ? remaining : nil
        guard remaining <= 0, opened.remove(app) != nil else { return }
        runtime.quit(app)
    }
}
#endif
