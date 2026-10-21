import Foundation
import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Bleep, page, metadata and rename editors")
struct PageAndFileEditorTests {
    private let file = URL(fileURLWithPath: "/tmp/report.pdf")
    private let clip = ToolPreview(width: nil, height: nil, duration: 10, pageCount: nil, thumbnail: nil)
    private let pages = (1...4).map { Data("page \($0)".utf8) }

    @Test("bleep starts with a one-second selection and merges overlapping spans")
    func bleep() async {
        let sut = BleepEditorViewModel(item: file, format: nil, previews: FakePreviewProvider(clip))
        await sut.load()
        #expect(sut.end == 1 && sut.settings == nil)
        sut.addSpan()
        sut.start = 5
        sut.end = 6
        sut.addSpan()
        sut.start = 0.5
        sut.end = 2
        sut.addSpan()
        #expect(sut.settings == .bleep([TimeSpan(start: 0, end: 2), TimeSpan(start: 5, end: 6)]))
        sut.remove(TimeSpan(start: 0, end: 2))
        #expect(sut.spans == [TimeSpan(start: 5, end: 6)])
    }

    @Test("bleep refuses too-short spans and clips without a length")
    func bleepInvalid() async {
        let sut = BleepEditorViewModel(item: file, format: nil, previews: FakePreviewProvider(clip))
        await sut.load()
        sut.end = 0.05
        sut.addSpan()
        #expect(sut.spans.isEmpty && !sut.canAdd)
        let silent = BleepEditorViewModel(item: file, format: nil, previews: FakePreviewProvider(.empty))
        await silent.load()
        silent.addSpan()
        #expect(silent.settings == nil)
    }

    @Test("merging sorts spans and joins touching ones")
    func merge() {
        let merged = BleepEditorViewModel.merged([
            TimeSpan(start: 4, end: 5), TimeSpan(start: 1, end: 2), TimeSpan(start: 2, end: 3)
        ])
        #expect(merged == [TimeSpan(start: 1, end: 3), TimeSpan(start: 4, end: 5)])
    }

    @Test("reorganize applies only a changed order and keeps at least one page")
    func reorganize() async {
        let sut = ReorganizePagesEditorViewModel(item: file, previews: FakePreviewProvider(.empty, pages: pages))
        await sut.load()
        #expect(sut.order == [0, 1, 2, 3] && sut.settings == nil)
        sut.move(from: IndexSet(integer: 3), to: 0)
        #expect(sut.settings == .pages([3, 0, 1, 2]))
        sut.move(from: IndexSet([0, 1]), to: 4)
        #expect(sut.order == [1, 2, 3, 0])
        sut.remove(page: 2)
        #expect(sut.settings == .pages([1, 3, 0]))
        #expect(sut.thumbnail(ofPage: 3) == pages[3] && sut.thumbnail(ofPage: 9) == nil)
        sut.reset()
        #expect(sut.settings == nil)
        [0, 1, 2, 3].forEach { sut.remove(page: $0) }
        #expect(sut.order == [3])
    }

    @Test("reorganize has nothing to apply for an unreadable PDF")
    func reorganizeEmpty() async {
        let sut = ReorganizePagesEditorViewModel(item: file, previews: FakePreviewProvider(.empty))
        await sut.load()
        #expect(sut.order.isEmpty && sut.settings == nil)
    }

    @Test("extract needs some pages but not all, in page order")
    func extract() async {
        let sut = ExtractPagesEditorViewModel(item: file, previews: FakePreviewProvider(.empty, pages: pages))
        await sut.load()
        #expect(sut.settings == nil)
        sut.toggle(2)
        sut.toggle(0)
        sut.toggle(7)
        #expect(sut.settings == .pages([0, 2]))
        sut.toggle(2)
        #expect(sut.isSelected(0) && !sut.isSelected(2))
        sut.selectAll()
        #expect(sut.settings == nil)
        sut.selectNone()
        #expect(sut.selected.isEmpty)
    }

    @Test("metadata prefills current values and applies only real changes")
    func metadata() async {
        let reader = StubMetadataReader([.title: "Draft", .author: "Ali"])
        let sut = MetadataEditorViewModel(item: file, format: nil, reader: reader)
        #expect(sut.settings == nil)
        await sut.load()
        #expect(sut.title == "Draft" && sut.author == "Ali" && sut.comment.isEmpty)
        #expect(sut.settings == nil)
        sut.title = "Final  "
        sut.author = ""
        sut.comment = "   "
        #expect(sut.settings == .metadata([.title: "Final", .author: ""]))
        #expect(sut.fileName == "report.pdf")
    }

    @Test("rename previews names with extensions and counts across every file")
    func rename() {
        let items = (1...10).map { URL(fileURLWithPath: "/tmp/IMG_\($0).jpg") }
        let sut = RenameEditorViewModel(items: items)
        #expect(sut.rows.count == RenameEditorViewModel.previewLimit)
        #expect(sut.rows.first == RenameRow(id: 0, old: "IMG_1.jpg", new: "IMG_1 01.jpg"))
        #expect(sut.hiddenCount == 2)
        sut.pattern = "Trip "
        sut.insert(RenamePattern.numberToken)
        sut.start = 5
        #expect(sut.rows.last?.new == "Trip 12.jpg")
        #expect(sut.settings == .rename(pattern: "Trip {n}", start: 5))
    }

    @Test("rename has nothing to apply for blank or no-op patterns")
    func renameInvalid() {
        let sut = RenameEditorViewModel(items: [URL(fileURLWithPath: "/tmp/notes")])
        sut.pattern = "  "
        #expect(sut.settings == nil)
        sut.pattern = RenamePattern.nameToken
        #expect(sut.settings == nil)
        sut.pattern = "{name} final"
        #expect(sut.rows == [RenameRow(id: 0, old: "notes", new: "notes final")])
        #expect(sut.hiddenCount == 0)
    }
}
