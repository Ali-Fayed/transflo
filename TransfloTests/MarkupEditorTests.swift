import Foundation
import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Markup editors")
struct MarkupEditorTests {
    private let file = URL(fileURLWithPath: "/tmp/photo.png")
    private let image = ToolPreview(width: 400, height: 200, duration: nil, pageCount: nil, thumbnail: Data("t".utf8))
    private let pdf = FormatDescriptor(id: FormatID("pdf"), displayName: "PDF", extensions: ["pdf"], family: .document)

    private func point(_ x: Double, _ y: Double) -> UnitPoint {
        UnitPoint(x: x, y: y)
    }

    private func annotate() async -> AnnotateEditorViewModel {
        let sut = AnnotateEditorViewModel(item: file, format: nil, previews: FakePreviewProvider(image))
        await sut.load()
        return sut
    }

    @Test("a box drag becomes one rectangle in the chosen color and thickness")
    func box() async {
        let sut = await annotate()
        #expect(sut.settings == nil)
        sut.color = "#3E63DD"
        sut.weight = .thick
        sut.begin(at: point(0.1, 0.1))
        sut.move(to: point(0.3, 0.2))
        sut.move(to: point(0.5, 0.4))
        #expect(sut.marks.count == 1 && sut.annotations.isEmpty)
        sut.end()
        let expected = Annotation(kind: .rectangle, points: [point(0.1, 0.1), point(0.5, 0.4)],
                                  color: "#3E63DD", weight: MarkupWeight.thick.rawValue)
        #expect(sut.settings == .annotate([expected]))
        #expect(sut.draft == nil)
    }

    @Test("pen strokes keep every point; arrows keep only the ends")
    func penAndArrow() async {
        let sut = await annotate()
        sut.tool = .pen
        sut.begin(at: point(0, 0))
        sut.move(to: point(0.1, 0.1))
        sut.move(to: point(0.2, 0.1))
        sut.end()
        sut.tool = .arrow
        sut.begin(at: point(0.5, 0.5))
        sut.move(to: point(0.6, 0.6))
        sut.move(to: point(0.9, 0.9))
        sut.end()
        #expect(sut.annotations.map(\.points.count) == [3, 2])
        #expect(sut.annotations.map(\.kind) == [.freehand, .arrow])
    }

    @Test("clicks without a drag draw nothing; a lone pen dot is dropped")
    func strayClicks() async {
        let sut = await annotate()
        sut.begin(at: point(0.5, 0.5))
        sut.move(to: point(0.502, 0.5))
        sut.end()
        sut.tool = .pen
        sut.begin(at: point(0.2, 0.2))
        sut.end()
        #expect(sut.annotations.isEmpty && sut.settings == nil)
        sut.move(to: point(0.3, 0.3))
        #expect(sut.draft == nil)
    }

    @Test("text mode places trimmed text on click and ignores empty text")
    func text() async {
        let sut = await annotate()
        sut.tool = .text
        sut.text = "   "
        sut.begin(at: point(0.2, 0.3))
        #expect(sut.annotations.isEmpty)
        sut.text = "  Look here "
        sut.begin(at: point(0.2, 0.3))
        sut.end()
        #expect(sut.annotations.map(\.kind) == [.text("Look here")])
        #expect(sut.annotations.first?.points == [point(0.2, 0.3)])
    }

    @Test("undo removes the last mark; clear removes all")
    func undoAndClear() async {
        let sut = await annotate()
        for offset in [0.0, 0.3] {
            sut.begin(at: point(offset, offset))
            sut.move(to: point(offset + 0.2, offset + 0.2))
            sut.end()
        }
        sut.undo()
        #expect(sut.annotations.count == 1)
        sut.clear()
        #expect(sut.settings == nil)
        sut.undo()
        #expect(sut.annotations.count == 1)
        #expect(sut.canRedo)
        sut.redo()
        #expect(sut.annotations.isEmpty)
    }

    @Test("drawing is ignored until the preview is available")
    func notLoaded() async {
        let sut = AnnotateEditorViewModel(item: file, format: pdf, previews: FakePreviewProvider(.empty))
        sut.begin(at: point(0, 0))
        sut.move(to: point(0.5, 0.5))
        sut.end()
        #expect(sut.annotations.isEmpty && sut.settings == nil)
        #expect(sut.isPDF)
    }

    @Test("redact boxes normalize any drag direction and skip slivers")
    func redact() async throws {
        let sut = RedactEditorViewModel(item: file, format: nil, previews: FakePreviewProvider(image))
        await sut.load()
        sut.begin(at: point(0.6, 0.5))
        sut.move(to: point(0.2, 0.1))
        #expect(sut.allBoxes.count == 1 && sut.boxes.isEmpty)
        sut.end()
        sut.begin(at: point(0.1, 0.1))
        sut.move(to: point(0.5, 0.105))
        sut.end()
        let box = try #require(sut.boxes.first)
        #expect(sut.boxes.count == 1 && sut.settings == .redact(sut.boxes))
        #expect([box.x - 0.2, box.y - 0.1, box.width - 0.4, box.height - 0.4].allSatisfy { abs($0) < 1e-9 })
        sut.undo()
        #expect(sut.settings == nil)
        sut.move(to: point(0.9, 0.9))
        #expect(sut.draft == nil)
    }

    @Test("add background uses the chosen color once the image is loaded")
    func background() async {
        let sut = AddBackgroundEditorViewModel(item: file, format: nil, previews: FakePreviewProvider(image))
        #expect(sut.settings == nil)
        await sut.load()
        #expect(sut.settings == .addBackground(color: AppMarkupPalette.defaultBackground))
        sut.color = "#111111"
        #expect(sut.settings == .addBackground(color: "#111111"))
    }

    @Test("collage defaults to the squarest grid and needs two images", arguments: [
        (1, 1), (2, 2), (4, 2), (5, 3), (10, 4)
    ])
    func collageColumns(count: Int, columns: Int) {
        #expect(CollageEditorViewModel.defaultColumns(for: count) == columns)
    }

    @Test("collage loads a thumbnail per image and validates columns and gap")
    func collage() async {
        let items = (1...3).map { URL(fileURLWithPath: "/tmp/\($0).png") }
        let sut = CollageEditorViewModel(items: items, formats: [nil, nil, nil], previews: FakePreviewProvider(image))
        await sut.load()
        #expect(sut.thumbnails.count == 3)
        #expect(sut.settings == .collage(columns: 2, spacing: 16, background: AppMarkupPalette.defaultBackground))
        sut.columns = 4
        #expect(sut.settings == nil)
        sut.columns = 3
        sut.spacing = -1
        #expect(sut.settings == nil)
        let single = CollageEditorViewModel(items: [file], formats: [nil], previews: FakePreviewProvider(image))
        #expect(single.settings == nil)
    }
}
