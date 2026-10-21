import Foundation
import Observation
import TransfloDomain

/// Rename with pattern: a name template with `{name}` and `{n}`, previewed live.
@Observable
final class RenameEditorViewModel: ToolEditorModel {
    static let defaultPattern = "\(RenamePattern.nameToken) \(RenamePattern.numberToken)"
    static let startRange = 0...99_999
    /// Rows shown in the preview; the rest are summarized.
    static let previewLimit = 8

    var pattern = defaultPattern
    var start = 1

    @ObservationIgnored private let items: [URL]

    init(items: [URL]) {
        self.items = items
    }

    var rows: [RenameRow] {
        let prefix = Array(items.prefix(Self.previewLimit))
        return zip(prefix, newNames(for: prefix)).enumerated().map { index, pair in
            RenameRow(id: index, old: pair.0.lastPathComponent, new: pair.1)
        }
    }

    var hiddenCount: Int { max(0, items.count - Self.previewLimit) }

    var settings: ToolSettings? {
        guard !pattern.trimmingCharacters(in: .whitespaces).isEmpty,
              newNames(for: items) != items.map(\.lastPathComponent) else { return nil }
        return .rename(pattern: pattern, start: start)
    }

    func load() async {}

    func insert(_ token: String) {
        pattern += token
    }

    /// Numbers count across every file, so a preview of the first few matches the real run.
    private func newNames(for urls: [URL]) -> [String] {
        let names = RenamePattern.names(pattern, originals: items.map { $0.deletingPathExtension().lastPathComponent },
                                        start: start)
        return zip(urls, names).map { url, name in
            url.pathExtension.isEmpty ? name : "\(name).\(url.pathExtension)"
        }
    }
}
