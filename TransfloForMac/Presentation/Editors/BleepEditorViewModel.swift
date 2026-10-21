import Foundation
import Observation
import TransfloDomain

/// Bleep: mark stretches of the clip to cover with a tone.
@Observable
final class BleepEditorViewModel: ToolEditorModel {
    static let minimumLength = 0.1
    /// Length of the stretch selected when the editor opens.
    static let initialLength = 1.0

    private(set) var preview: ToolPreview = .empty
    private(set) var spans: [TimeSpan] = []
    var start = 0.0
    var end = 0.0

    @ObservationIgnored let item: URL
    @ObservationIgnored private let format: FormatDescriptor?
    @ObservationIgnored let previews: any ToolPreviewProviding

    init(item: URL, format: FormatDescriptor?, previews: any ToolPreviewProviding) {
        self.item = item
        self.format = format
        self.previews = previews
    }

    var duration: Double {
        guard let duration = preview.duration, duration.isFinite, duration > 0 else { return 0 }
        return duration
    }
    var canAdd: Bool {
        duration.isFinite && duration > 0 && start.isFinite && end.isFinite
            && start >= 0 && end <= duration && end - start >= Self.minimumLength
    }
    func clear() { spans.removeAll() }
    func nextSelection() {
        guard end.isFinite, end < duration else { return }
        start = end
        end = min(duration, start + Self.initialLength)
    }

    var settings: ToolSettings? {
        guard duration.isFinite, duration > 0, !spans.isEmpty else { return nil }
        return .bleep(spans)
    }

    func load() async {
        preview = await previews.preview(of: item, format: format)
        start = 0
        end = min(Self.initialLength, duration)
    }

    /// Adds the selected stretch, joining it with any it overlaps.
    func addSpan() {
        guard canAdd else { return }
        spans = Self.merged(spans + [TimeSpan(start: start, end: end)])
    }

    func remove(_ span: TimeSpan) {
        spans.removeAll { $0 == span }
    }

    /// Sorted by start, with overlapping or touching spans joined.
    static func merged(_ spans: [TimeSpan]) -> [TimeSpan] {
        spans.sorted { $0.start < $1.start }.reduce(into: []) { result, span in
            if let last = result.last, span.start <= last.end {
                result[result.count - 1] = TimeSpan(start: last.start, end: max(last.end, span.end))
            } else {
                result.append(span)
            }
        }
    }
}
