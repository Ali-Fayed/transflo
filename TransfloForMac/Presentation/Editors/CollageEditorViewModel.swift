import Foundation
import Observation
import TransfloDomain

/// Collage: the dropped images in a grid with a gap and a background color.
@Observable
final class CollageEditorViewModel: ToolEditorModel {
    static let spacingRange = 0...200
    /// Thumbnails shown in the preview; the collage itself uses every image.
    static let previewLimit = 24

    private(set) var thumbnails: [Data?] = []
    var columns: Int
    var spacing = 16
    var background = AppMarkupPalette.defaultBackground
    private(set) var order: [Int]
    var cellWidth = 640
    var cellHeight = 480
    var fill = false
    private(set) var composed: Data?
    private(set) var renderError: L10nKey?
    @ObservationIgnored private let inspector: (any ToolInspectionProviding)?
    @ObservationIgnored private var rendered: CollageSettings?
    @ObservationIgnored private var revision = 0

    @ObservationIgnored let items: [URL]
    @ObservationIgnored private let formats: [FormatDescriptor?]
    @ObservationIgnored private let previews: any ToolPreviewProviding

    init(
        items: [URL],
        formats: [FormatDescriptor?],
        previews: any ToolPreviewProviding,
        inspector: (any ToolInspectionProviding)? = nil
    ) {
        self.items = items
        self.formats = formats
        self.previews = previews
        self.inspector = inspector
        order = Array(items.indices)
        columns = Self.defaultColumns(for: items.count)
    }

    var imageCount: Int { order.count }
    var columnRange: ClosedRange<Int> { 1...max(1, order.count) }

    var layoutSettings: CollageSettings {
        CollageSettings(order: order, columns: columns, spacing: spacing, background: background,
                        cellWidth: cellWidth, cellHeight: cellHeight, fill: fill)
    }
    var settings: ToolSettings? {
        guard layoutSettings.isValid else { return nil }
        if inspector != nil {
            guard rendered == layoutSettings, composed != nil else { return nil }
            return .collageLayout(layoutSettings)
        }
        return .collage(columns: columns, spacing: spacing, background: background)
    }
    var orderedThumbnails: [Data?] { order.map { thumbnails.indices.contains($0) ? thumbnails[$0] : nil } }

    func load() async {
        var loaded: [Data?] = []
        for (item, format) in zip(items, formats).prefix(Self.previewLimit) {
            loaded.append(await previews.preview(of: item, format: format).thumbnail)
        }
        thumbnails = loaded
        if let first = items.first, let format = formats.first {
            let fact = await previews.preview(of: first, format: format)
            cellWidth = min(1200, max(1, fact.width ?? 640))
            cellHeight = min(4096, max(1, Int(Double(cellWidth) * Double(fact.height ?? 480)
                                               / Double(max(1, fact.width ?? 640)))))
        }
        await renderPreview()
    }

    func renderPreview() async {
        guard let inspector else { return }
        revision += 1
        let version = revision
        let settings = layoutSettings
        guard settings.isValid else { return }
        do {
            let data = try await inspector.collage(items: items, settings: settings)
            guard !Task.isCancelled, version == revision else { return }
            composed = data; rendered = settings; renderError = nil
        } catch {
            guard !Task.isCancelled, version == revision else { return }
            composed = nil; rendered = nil
            renderError = JobPresentation.message(for: error)
        }
    }

    func move(from indices: IndexSet, to destination: Int) {
        let source = indices.filter { order.indices.contains($0) }
        let moving = source.map { order[$0] }
        let target = min(max(0, destination), order.count)
        for index in source.reversed() { order.remove(at: index) }
        order.insert(contentsOf: moving, at: target - source.filter { $0 < target }.count)
    }
    func shift(_ item: Int, by offset: Int) {
        guard let index = order.firstIndex(of: item), order.indices.contains(index + offset) else { return }
        order.swapAt(index, index + offset)
    }
    func remove(_ item: Int) {
        order.removeAll { $0 == item }
        columns = min(columns, max(1, order.count))
    }

    var rows: Int { (imageCount + max(1, columns) - 1) / max(1, columns) }
    var layout: Int { columns == 1 ? 2 : (columns == imageCount ? 1 : 0) }
    func applyLayout(_ preset: Int) {
        columns = preset == 1 ? max(1, imageCount) : (preset == 2 ? 1 : Self.defaultColumns(for: imageCount))
    }
    func reset() {
        columns = Self.defaultColumns(for: imageCount)
        spacing = 16
        background = AppMarkupPalette.defaultBackground
    }

    /// The squarest grid: 2 → 2, 4 → 2, 5 → 3, 10 → 4.
    static func defaultColumns(for count: Int) -> Int {
        max(1, Int(Double(count).squareRoot().rounded(.up)))
    }
}
