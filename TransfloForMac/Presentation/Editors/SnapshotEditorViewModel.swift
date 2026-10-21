import Foundation
import Observation
import TransfloDomain

/// Snapshot: pick a moment and save that frame as an image.
@Observable
final class SnapshotEditorViewModel: ToolEditorModel {
    private(set) var preview: ToolPreview = .empty
    private(set) var frame: Data?
    var time = 0.0
    var jpeg = false
    var quality = 90

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

    var maximumTime: Double { duration.isFinite ? max(0, duration) : 0 }
    var settings: ToolSettings? {
        guard duration.isFinite, duration > 0, time.isFinite, (0...maximumTime).contains(time) else { return nil }
        guard (1...100).contains(quality) else { return nil }
        return jpeg ? .snapshotJPEG(at: time, quality: quality) : .snapshot(at: time)
    }
    func selectFraction(_ fraction: Double) { time = maximumTime * min(max(fraction, 0), 1) }

    var frameRate: Double {
        guard let rate = preview.frameRate, rate.isFinite, rate > 0 else { return 30 }
        return rate
    }
    func stepFrame(_ direction: Int) {
        time = min(maximumTime, max(0, time + Double(direction) / frameRate))
    }

    func load() async {
        preview = await previews.preview(of: item, format: format)
        frame = preview.thumbnail
    }

    /// Fetches the frame at `time` (the view debounces calls).
    func refreshFrame() async {
        guard settings != nil else { return }
        let requested = time
        let image = await previews.frame(of: item, at: requested)
        if requested == time, let image { frame = image }
    }
}
