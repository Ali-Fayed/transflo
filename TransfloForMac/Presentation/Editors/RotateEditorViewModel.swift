import Foundation
import Observation
import TransfloDomain

/// Quarter turns and mirroring share the existing geometry operation with export.
@Observable
final class RotateEditorViewModel: ToolEditorModel {
    private(set) var preview: ToolPreview = .empty
    var quarterTurns = 1
    var flipHorizontal = false
    var flipVertical = false
    var supportsMirroring: Bool { format?.id.rawValue != "pdf" }
    private let item: URL
    private let format: FormatDescriptor?
    private let previews: any ToolPreviewProviding

    init(item: URL, format: FormatDescriptor?, previews: any ToolPreviewProviding) {
        self.item = item; self.format = format; self.previews = previews
    }
    var outputSize: (width: Int, height: Int)? {
        guard let width = preview.width, let height = preview.height else { return nil }
        return quarterTurns.isMultiple(of: 2) ? (width, height) : (height, width)
    }
    var settings: ToolSettings? {
        guard preview.thumbnail != nil, (0...3).contains(quarterTurns),
              supportsMirroring || (!flipHorizontal && !flipVertical),
              quarterTurns != 0 || flipHorizontal || flipVertical else { return nil }
        return .rotate(quarterTurns: quarterTurns, flipHorizontal: flipHorizontal, flipVertical: flipVertical)
    }
    func load() async { preview = await previews.preview(of: item, format: format) }
    func reset() { quarterTurns = 0; flipHorizontal = false; flipVertical = false }
}
