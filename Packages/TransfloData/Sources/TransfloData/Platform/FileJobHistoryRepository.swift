import Foundation
import os
import TransfloDomain

/// Stores job history as JSON in one file (atomic writes); an unreadable file reads as empty.
public struct FileJobHistoryRepository: JobHistoryRepository {
    private static let logger = Logger(subsystem: "com.transflo.app", category: "History")
    private let file: URL

    /// - Parameter file: Usually `history.json` in Application Support.
    public init(file: URL) {
        self.file = file
    }

    public func load() -> [JobHistoryEntry] {
        guard let data = try? Data(contentsOf: file) else { return [] }
        do {
            return try JSONDecoder().decode([JobHistoryEntry].self, from: data)
        } catch {
            Self.logger.error("History unreadable: \(String(describing: error), privacy: .public)")
            return []
        }
    }

    public func save(_ entries: [JobHistoryEntry]) {
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try JSONEncoder().encode(entries).write(to: file, options: .atomic)
        } catch {
            Self.logger.error("History not saved: \(String(describing: error), privacy: .public)")
        }
    }
}
