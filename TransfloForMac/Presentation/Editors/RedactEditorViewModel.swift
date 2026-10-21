import Foundation
import Observation
import TransfloDomain

/// Redact: black boxes dragged over the image (or a PDF's first page).
@Observable
final class RedactEditorViewModel: ToolEditorModel {
    /// Smallest box side (unit coordinates) that counts as a deliberate box.
    static let minimumSide = 0.01

    private(set) var preview: ToolPreview = .empty
    var boxes: [NormalizedRect] { history.marks }
    private(set) var draft: NormalizedRect?
    @ObservationIgnored private var anchor: UnitPoint?
    @ObservationIgnored private var isLargeEnough = false

    private(set) var history = PagedMarkHistory<NormalizedRect>()
    var canUndo: Bool { history.canUndo }
    var canRedo: Bool { history.canRedo }
    var selectedPage: Int { history.page }
    private(set) var pageCount = 1
    var editedPageCount: Int { history.changesByPage.count }

    @ObservationIgnored private let item: URL
    @ObservationIgnored private let format: FormatDescriptor?
    @ObservationIgnored private let previews: any ToolPreviewProviding

    init(item: URL, format: FormatDescriptor?, previews: any ToolPreviewProviding) {
        self.item = item
        self.format = format
        self.previews = previews
    }

    var isPDF: Bool { format?.id.rawValue == "pdf" }

    /// Finished boxes plus the one being dragged.
    var allBoxes: [NormalizedRect] { draft.map { boxes + [$0] } ?? boxes }

    var settings: ToolSettings? {
        guard preview.thumbnail != nil else { return nil }
        if isPDF { return history.changesByPage.isEmpty ? nil : .pageRedactions(history.changesByPage) }
        return boxes.isEmpty ? nil : .redact(boxes)
    }

    func load() async {
        preview = await previews.preview(of: item, format: format)
        pageCount = max(1, preview.pageCount ?? 1)
    }

    func selectPage(_ index: Int) async {
        guard isPDF, (0..<pageCount).contains(index), index != selectedPage else { return }
        history.select(page: index)
        draft = nil
        preview = .empty
        let loaded = await previews.pagePreview(of: item, index: index)
        guard index == selectedPage, !Task.isCancelled else { return }
        preview = loaded
    }

    func begin(at point: UnitPoint) {
        guard preview.thumbnail != nil else { return }
        anchor = point
        move(to: point)
    }

    func move(to point: UnitPoint) {
        guard let anchor else { return }
        let width = abs(point.x - anchor.x)
        let height = abs(point.y - anchor.y)
        isLargeEnough = width >= Self.minimumSide && height >= Self.minimumSide
        draft = NormalizedRect(x: min(anchor.x, point.x), y: min(anchor.y, point.y), width: width, height: height)
    }

    /// Keeps the box unless it is too thin to mean anything.
    func end() {
        defer {
            draft = nil
            anchor = nil
        }
        guard let draft, isLargeEnough else { return }
        commit(boxes + [draft])
    }

    func undo() {
        history.undo()
        draft = nil
    }
    func redo() {
        history.redo()
        draft = nil
    }
    func clear() { commit([]); draft = nil }
    func remove(at index: Int) { history.remove(at: index) }
    private func commit(_ next: [NormalizedRect]) { history.commit(next) }
}
