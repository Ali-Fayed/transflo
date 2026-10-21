import Foundation
import Observation
import TransfloDomain

/// Trim: keep the part between two times.
@Observable
final class TrimEditorViewModel: ToolEditorModel {
    static let minimumLength = 0.1

    private(set) var preview: ToolPreview = .empty
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

    var settings: ToolSettings? {
        guard duration.isFinite, duration > 0, start.isFinite, end.isFinite, start >= 0, end <= duration,
              end - start >= Self.minimumLength, start > 0 || end < duration else { return nil }
        return .trim(start: start, end: end)
    }

    func selectFraction(_ lower: Double, _ upper: Double) { start = duration * lower; end = duration * upper }
    func reset() { start = 0; end = duration }

    func load() async {
        preview = await previews.preview(of: item, format: format)
        start = 0
        end = duration
    }
}
