import Foundation
import Observation
import TransfloDomain

/// Extract pages: pick the pages that go into a new PDF.
@Observable
final class ExtractPagesEditorViewModel: ToolEditorModel {
    private(set) var thumbnails: [Data] = []
    private(set) var selected: Set<Int> = []
    var rangeText = ""
    private(set) var rangeInvalid = false

    @ObservationIgnored private let item: URL
    @ObservationIgnored private let previews: any ToolPreviewProviding

    init(item: URL, previews: any ToolPreviewProviding) {
        self.item = item
        self.previews = previews
    }

    var pageCount: Int { thumbnails.count }

    /// Some pages, but not all of them (that would be a plain copy).
    var settings: ToolSettings? {
        guard !selected.isEmpty, selected.count < pageCount else { return nil }
        return .pages(selected.sorted())
    }

    func load() async {
        thumbnails = await previews.pageThumbnails(of: item)
    }

    func isSelected(_ page: Int) -> Bool {
        selected.contains(page)
    }

    func toggle(_ page: Int) {
        guard (0..<pageCount).contains(page) else { return }
        if selected.remove(page) == nil { selected.insert(page) }
    }

    func selectOdd() { selected = Set((0..<pageCount).filter { $0.isMultiple(of: 2) }) }
    func selectEven() { selected = Set((0..<pageCount).filter { !$0.isMultiple(of: 2) }) }
    func invert() { selected = Set(0..<pageCount).subtracting(selected) }
    func applyRange() {
        guard let pages = PageRangeSelection.parse(rangeText, pageCount: pageCount) else {
            rangeInvalid = true
            return
        }
        selected = pages
        rangeInvalid = false
    }

    func selectAll() {
        selected = Set(0..<pageCount)
    }

    func selectNone() {
        selected.removeAll()
    }
}
