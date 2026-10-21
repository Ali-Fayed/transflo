import Foundation
import TransfloDomain

/// Converts between a live job and its stored history entry (Mapper pattern).
enum JobHistoryMapper {
    /// The entry for a finished `record`, with outputs relative to `root` (outputs outside it are dropped).
    static func entry(from record: JobRecord, root: URL, finishedAt: Date) -> JobHistoryEntry {
        let base = root.standardizedFileURL.path + "/"
        let outputs = record.completedOutputs.compactMap { url -> String? in
            let path = url.standardizedFileURL.path
            return path.hasPrefix(base) ? String(path.dropFirst(base.count)) : nil
        }
        let row = JobRow(record)
        let failed: Bool
        if case .failed = record.state { failed = true } else { failed = false }
        return JobHistoryEntry(id: record.id, finishedAt: finishedAt, title: text(row.operation),
                               files: text(row.files), outputs: outputs, failed: failed)
    }

    static func text(_ content: AppTextContent) -> JobHistoryEntry.Text {
        switch content {
        case .key(let key): .init(key: key.rawValue)
        case let .formatted(key, arguments): .init(key: key.rawValue, arguments: arguments)
        case .verbatim(let value): .init(key: nil, verbatim: value)
        }
    }

    /// Stored text back as displayable content; a key this version doesn't know shows nothing broken.
    static func content(_ text: JobHistoryEntry.Text) -> AppTextContent {
        guard let raw = text.key, let key = L10nKey(rawValue: raw) else { return .verbatim(text.verbatim ?? "") }
        return text.arguments.isEmpty ? .key(key) : .formatted(key, text.arguments)
    }
}
