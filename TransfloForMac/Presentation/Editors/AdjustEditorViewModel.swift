import Foundation
import Observation
import TransfloDomain

/// Photo adjustments with original comparison and a shared preview/export pipeline.
@Observable
final class AdjustEditorViewModel: ToolEditorModel {
    private(set) var preview: ToolPreview = .empty
    private(set) var adjustedThumbnail: Data?
    var values = ImageAdjustments.neutral
    var showOriginal = false

    // Preserve the simple bindings used by existing callers.
    var exposure: Double { get { values.exposure } set { values.exposure = newValue } }
    var contrast: Double { get { values.contrast } set { values.contrast = newValue } }
    var saturation: Double { get { values.saturation } set { values.saturation = newValue } }

    @ObservationIgnored private let item: URL
    @ObservationIgnored private let format: FormatDescriptor?
    @ObservationIgnored private let previews: any ToolPreviewProviding

    init(item: URL, format: FormatDescriptor?, previews: any ToolPreviewProviding) {
        self.item = item
        self.format = format
        self.previews = previews
    }

    var adjustments: ImageAdjustments { values.validated }
    var displayedThumbnail: Data? { showOriginal ? preview.thumbnail : adjustedThumbnail }
    var settings: ToolSettings? { adjustments.isNeutral ? nil : .adjust(adjustments) }

    func load() async {
        preview = await previews.preview(of: item, format: format)
        adjustedThumbnail = preview.thumbnail
        if !adjustments.isNeutral { await refreshPreview() }
    }

    /// Only the newest settings can publish a preview; late renders cannot replace newer edits.
    func refreshPreview() async {
        guard let thumbnail = preview.thumbnail else { return }
        let requested = adjustments
        if requested.isNeutral { adjustedThumbnail = thumbnail; return }
        let rendered = await previews.adjusted(thumbnail, with: requested)
        if !Task.isCancelled && requested == adjustments { adjustedThumbnail = rendered ?? thumbnail }
    }

    func reset() {
        values = .neutral
        adjustedThumbnail = preview.thumbnail
        showOriginal = false
    }
}
