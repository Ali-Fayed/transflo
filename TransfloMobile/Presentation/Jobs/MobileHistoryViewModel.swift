import Foundation
import Observation
import TransfloDomain

/// Finished jobs from earlier sessions, read from the stored history, with their results to share.
@Observable
final class MobileHistoryViewModel {
    private(set) var entries: [JobHistoryEntry]

    @ObservationIgnored private let repository: any JobHistoryRepository
    @ObservationIgnored private let record: RecordJobHistoryUseCase
    @ObservationIgnored private let root: URL
    @ObservationIgnored private let share: ([URL]) -> Void
    @ObservationIgnored private let now: () -> Date

    init(
        repository: any JobHistoryRepository,
        root: URL,
        share: @escaping ([URL]) -> Void,
        now: @escaping () -> Date = { Date() }
    ) {
        self.repository = repository
        self.record = RecordJobHistoryUseCase(repository: repository)
        self.root = root
        self.share = share
        self.now = now
        entries = repository.load()
    }

    /// Entries not shown live in this session (`liveIDs` are the jobs the History list already has).
    func earlier(excluding liveIDs: Set<UUID>) -> [JobHistoryEntry] {
        entries.filter { !liveIDs.contains($0.id) }
    }

    /// Remembers a job that just finished.
    func finished(_ job: JobRecord) {
        record.execute(JobHistoryMapper.entry(from: job, root: root, finishedAt: now()))
        entries = repository.load()
    }

    /// Results of `entry` that still exist in the workspace.
    func outputs(of entry: JobHistoryEntry) -> [URL] {
        entry.outputs.map { root.appendingPathComponent($0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    func shareOutputs(of entry: JobHistoryEntry) {
        share(outputs(of: entry))
    }

    /// Removes one entry from Activity; its results stay in Converted Files.
    func delete(_ id: UUID) {
        record.remove(id)
        entries.removeAll { $0.id == id }
    }

    func clear() {
        record.clear()
        entries = []
    }
}
