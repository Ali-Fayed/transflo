import Foundation
import Observation
import TransfloDomain

/// Annotate: boxes, arrows, pen strokes and text over the image (or a PDF's first page).
@Observable
final class AnnotateEditorViewModel: ToolEditorModel {
    /// Shortest drag (unit distance) that counts as a box or arrow rather than a stray click.
    static let minimumDrag = 0.01

    private(set) var preview: ToolPreview = .empty
    var annotations: [Annotation] { history.marks }
    private(set) var draft: Annotation?
    var tool = MarkupTool.box
    var color = AppMarkupPalette.defaultInk
    var weight = MarkupWeight.medium
    var text = ""

    private(set) var history = PagedMarkHistory<Annotation>()
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

    /// Finished marks plus the one being drawn.
    var marks: [Annotation] { draft.map { annotations + [$0] } ?? annotations }

    var settings: ToolSettings? {
        guard preview.thumbnail != nil else { return nil }
        if isPDF { return history.changesByPage.isEmpty ? nil : .pageAnnotations(history.changesByPage) }
        return annotations.isEmpty ? nil : .annotate(annotations)
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

    /// Starts a mark; in Text mode a click places the typed text right away.
    func begin(at point: UnitPoint) {
        guard preview.thumbnail != nil else { return }
        switch tool {
        case .text:
            let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { return }
            commit(annotations + [mark(.text(content), [point])])
        case .pen: draft = mark(.freehand, [point])
        case .box: draft = mark(.rectangle, [point, point])
        case .arrow: draft = mark(.arrow, [point, point])
        }
    }

    func move(to point: UnitPoint) {
        guard let current = draft, let first = current.points.first else { return }
        let points = current.kind == .freehand ? current.points + [point] : [first, point]
        draft = Annotation(kind: current.kind, points: points, color: current.color, weight: current.weight)
    }

    /// Keeps the drawn mark unless it was only a click.
    func end() {
        defer { draft = nil }
        guard let current = draft, Self.isVisible(current) else { return }
        commit(annotations + [current])
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
    private func commit(_ next: [Annotation]) { history.commit(next) }

    private func mark(_ kind: Annotation.Kind, _ points: [UnitPoint]) -> Annotation {
        Annotation(kind: kind, points: points, color: color, weight: weight.rawValue)
    }

    private static func isVisible(_ mark: Annotation) -> Bool {
        guard let first = mark.points.first, let last = mark.points.last else { return false }
        if mark.kind == .freehand { return mark.points.count > 1 }
        return hypot(last.x - first.x, last.y - first.y) >= minimumDrag
    }
}
