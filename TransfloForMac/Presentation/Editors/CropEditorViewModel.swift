import Foundation
import Observation
import TransfloDomain

/// Crop: a box over the image or first video frame, free or locked to an aspect ratio.
@Observable
final class CropEditorViewModel: ToolEditorModel {
    private(set) var preview: ToolPreview = .empty
    private(set) var rect = NormalizedRect.full
    private(set) var aspect = CropAspect.free
    var showsGrid = true

    @ObservationIgnored private let item: URL
    @ObservationIgnored private let format: FormatDescriptor?
    @ObservationIgnored private let previews: any ToolPreviewProviding

    init(item: URL, format: FormatDescriptor?, previews: any ToolPreviewProviding) {
        self.item = item
        self.format = format
        self.previews = previews
    }

    var settings: ToolSettings? {
        guard preview.thumbnail != nil, preview.width != nil, rect != .full else { return nil }
        return .crop(rect)
    }

    var outputPixels: PixelRect {
        rect.pixels(width: preview.width ?? 1, height: preview.height ?? 1, even: format?.family == .video)
    }
    func nudge(x: Int, y: Int) { setPosition(x: pixelX + x, y: pixelY + y) }

    func load() async {
        let loaded = await previews.preview(of: item, format: format)
        guard !Task.isCancelled else { return }
        preview = loaded
    }

    /// Switches the aspect preset and centers the largest box of that shape.
    func select(_ aspect: CropAspect) {
        self.aspect = aspect
        guard let ratio = currentRatio else { return }
        var width = 1.0
        var height = normalizedHeight(forWidth: width, ratio: ratio)
        if height > 1 {
            width /= height
            height = 1
        }
        rect = NormalizedRect(x: (1 - width) / 2, y: (1 - height) / 2, width: width, height: height)
    }

    /// Applies a proposal from the overlay, keeping the aspect ratio when one is selected.
    func propose(_ proposal: NormalizedRect) {
        guard let ratio = currentRatio else {
            rect = proposal
            return
        }
        var width = proposal.width
        var height = normalizedHeight(forWidth: width, ratio: ratio)
        if height > 1 {
            width /= height
            height = 1
        }
        rect = NormalizedRect(x: proposal.x, y: proposal.y, width: width, height: height)
    }

    var pixelWidth: Int { pixelRect?.width ?? 0 }
    var pixelHeight: Int { pixelRect?.height ?? 0 }
    var pixelX: Int { pixelRect?.x ?? 0 }
    var pixelY: Int { pixelRect?.y ?? 0 }
    var maximumWidth: Int { max(1, preview.width ?? 1) }
    var maximumHeight: Int { max(1, preview.height ?? 1) }

    func setWidth(_ width: Int) {
        guard width > 0, preview.width != nil else { return }
        let proposedWidth = Double(min(width, maximumWidth))
        let height = currentRatio.map { proposedWidth / $0 } ?? Double(pixelHeight)
        setPixels(width: proposedWidth, height: height)
    }

    func setHeight(_ height: Int) {
        guard height > 0, preview.height != nil else { return }
        let proposedHeight = Double(min(height, maximumHeight))
        let width = currentRatio.map { proposedHeight * $0 } ?? Double(pixelWidth)
        setPixels(width: width, height: proposedHeight)
    }

    func reset() {
        rect = .full
        aspect = .free
    }

    func setPosition(x: Int, y: Int) {
        guard preview.width != nil else { return }
        rect = NormalizedRect(x: Double(x) / Double(maximumWidth), y: Double(y) / Double(maximumHeight),
                              width: rect.width, height: rect.height)
    }

    func center() {
        rect = NormalizedRect(x: (1 - rect.width) / 2, y: (1 - rect.height) / 2,
                              width: rect.width, height: rect.height)
    }

    private var pixelRect: PixelRect? {
        guard let width = preview.width, let height = preview.height, width > 0, height > 0 else { return nil }
        return rect.pixels(width: width, height: height)
    }

    private func setPixels(width: Double, height: Double) {
        guard width.isFinite, height.isFinite, width > 0, height > 0 else { return }
        let imageWidth = Double(maximumWidth)
        let imageHeight = Double(maximumHeight)
        let scale = min(1, min(imageWidth / width, imageHeight / height))
        let normalizedWidth = width * scale / imageWidth
        let normalizedHeight = height * scale / imageHeight
        let centerX = rect.x + rect.width / 2
        let centerY = rect.y + rect.height / 2
        rect = NormalizedRect(x: centerX - normalizedWidth / 2, y: centerY - normalizedHeight / 2,
                              width: normalizedWidth, height: normalizedHeight,
                              minimumSize: 1 / max(imageWidth, imageHeight))
    }

    private var currentRatio: Double? {
        guard let width = preview.width, let height = preview.height else { return nil }
        return aspect.ratio(imageWidth: width, imageHeight: height)
    }

    /// Height in unit coordinates for a pixel aspect `ratio`, given the image's own proportions.
    private func normalizedHeight(forWidth width: Double, ratio: Double) -> Double {
        guard let imageWidth = preview.width, let imageHeight = preview.height, imageHeight > 0 else { return width }
        return width * Double(imageWidth) / (Double(imageHeight) * ratio)
    }
}
