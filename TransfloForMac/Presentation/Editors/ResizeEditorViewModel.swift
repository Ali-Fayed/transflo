import Foundation
import Observation
import TransfloDomain

/// Resize: width and height in pixels, optionally locked to the original proportions.
@Observable
final class ResizeEditorViewModel: ToolEditorModel {
    static let sizeRange = 1...16_384

    private(set) var preview: ToolPreview = .empty
    private(set) var width = 0
    private(set) var height = 0
    var keepsProportions = true

    @ObservationIgnored private let item: URL
    @ObservationIgnored private let format: FormatDescriptor?
    @ObservationIgnored private let previews: any ToolPreviewProviding

    init(item: URL, format: FormatDescriptor?, previews: any ToolPreviewProviding) {
        self.item = item
        self.format = format
        self.previews = previews
    }

    var settings: ToolSettings? {
        guard let sourceWidth = preview.width, let sourceHeight = preview.height,
              sourceWidth > 0, sourceHeight > 0, Self.sizeRange.contains(width),
              Self.sizeRange.contains(height), outputWidth > 0, outputHeight > 0 else { return nil }
        return .resize(width: width, height: height)
    }

    var outputWidth: Int { format?.family == .video ? width - width % 2 : width }
    var outputHeight: Int { format?.family == .video ? height - height % 2 : height }
    var enlarges: Bool { width > preview.width ?? width || height > preview.height ?? height }

    func load() async {
        preview = await previews.preview(of: item, format: format)
        width = preview.width ?? 0
        height = preview.height ?? 0
    }

    func setWidth(_ value: Int) {
        width = value
        if keepsProportions, let ratio { height = max(1, Int((Double(value) / ratio).rounded())) }
    }

    func setHeight(_ value: Int) {
        height = value
        if keepsProportions, let ratio { width = max(1, Int((Double(value) * ratio).rounded())) }
    }

    /// Scales the original size by `percent`.
    func scale(_ percent: Int) {
        guard let original = preview.width else { return }
        let proportional = keepsProportions
        keepsProportions = true
        setWidth(max(1, original * percent / 100))
        keepsProportions = proportional
    }

    var percentage = 50
    func applyPercentage() { scale(min(max(percentage, 1), 400)) }
    func fitLongEdge(_ edge: Int) {
        guard let width = preview.width, let height = preview.height, max(width, height) > 0 else { return }
        let factor = min(1, Double(edge) / Double(max(width, height)))
        self.width = max(1, Int((Double(width) * factor).rounded()))
        self.height = max(1, Int((Double(height) * factor).rounded()))
    }
    func reset() { width = preview.width ?? 0; height = preview.height ?? 0; keepsProportions = true }

    private var ratio: Double? {
        guard let width = preview.width, let height = preview.height, height > 0 else { return nil }
        return Double(width) / Double(height)
    }
}
