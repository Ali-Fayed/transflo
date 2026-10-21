import Foundation
import TransfloDomain

/// Runs every enabled watch folder: each new file that fits the folder's action becomes a background
/// job, and the job's results are remembered so Transflo never processes its own output again.
final class WatchFolderCoordinator {
    typealias WatcherFactory = (URL, @escaping ([URL]) -> Void) -> any FolderWatching

    private let repository: any WatchFolderRepository
    private let resolve: ResolveWatchActionUseCase
    private let jobs: any BackgroundJobScheduling
    private let makeWatcher: WatcherFactory
    private let fingerprint: (URL) -> String?
    private let isOwnOutput: (URL) -> Bool
    private var watchers: [UUID: any FolderWatching] = [:]
    /// Files Transflo wrote (results of watch jobs), by standardized path.
    private var produced: [String: String] = [:]
    private var inFlight: Set<String> = []

    init(
        repository: any WatchFolderRepository,
        resolve: ResolveWatchActionUseCase,
        jobs: any BackgroundJobScheduling,
        fingerprint: @escaping (URL) -> String? = { _ in nil },
        isOwnOutput: @escaping (URL) -> Bool = { _ in false },
        makeWatcher: @escaping WatcherFactory
    ) {
        self.repository = repository
        self.resolve = resolve
        self.jobs = jobs
        self.makeWatcher = makeWatcher
        self.fingerprint = fingerprint
        self.isOwnOutput = isOwnOutput
        jobs.observeFinishedJobs { [weak self] record in
            guard let self else { return }
            if record.isBackground { inFlight.subtract(record.items.map(Self.key)) }
            if produced.count > 10_000 { produced = [:] }
            for url in record.completedOutputs { produced[Self.key(url)] = fingerprint(url) }
        }
    }

    /// (Re)starts watching the enabled folders; call at launch and whenever Settings changes them.
    func reload() {
        watchers.values.forEach { $0.stop() }
        watchers = [:]
        for folder in repository.loadWatchFolders() where folder.isEnabled {
            let id = folder.id
            let watcher = makeWatcher(folder.folder) { [weak self] files in self?.handle(files, from: id) }
            if watcher.start() { watchers[id] = watcher }
        }
    }

    /// Whether a folder is being watched right now (a missing or unreadable folder isn't).
    func isWatching(_ id: WatchFolder.ID) -> Bool { watchers[id] != nil }

    private func handle(_ files: [URL], from id: WatchFolder.ID) {
        guard let folder = repository.loadWatchFolders().first(where: { $0.id == id }), folder.isEnabled else {
            return
        }
        for file in files {
            let key = Self.key(file)
            guard !inFlight.contains(key), !isOwnOutput(file) else { continue }
            if let saved = produced[key], saved == fingerprint(file) { continue }
            produced[key] = nil
            guard let option = resolve.execute(folder.action, for: file) else { continue }
            inFlight.insert(key)
            jobs.scheduleInBackground(option, items: [file])
        }
    }

    private static func key(_ url: URL) -> String { url.standardizedFileURL.path }
}
