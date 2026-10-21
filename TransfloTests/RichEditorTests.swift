import Foundation
import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Rich editor controls")
struct RichEditorTests {
    private let file = URL(fileURLWithPath: "/tmp/sample.png")
    private let image = ToolPreview(width: 400, height: 200, duration: nil, pageCount: nil, thumbnail: Data([1]))
    private let clip = ToolPreview(width: 640, height: 360, duration: 12, pageCount: nil, thumbnail: Data([1]))

    @Test("crop position clamps to its bounds and centers without changing dimensions")
    func cropPosition() async {
        let model = CropEditorViewModel(item: file, format: nil, previews: FakePreviewProvider(image))
        await model.load()
        model.setWidth(200)
        model.setHeight(100)
        model.setPosition(x: 400, y: 200)
        #expect(model.pixelX == 200 && model.pixelY == 100)
        model.center()
        #expect(model.pixelX == 100 && model.pixelY == 50)
        #expect(model.pixelWidth == 200 && model.pixelHeight == 100)
    }

    @Test("resize fit never enlarges and percentage and restore use source dimensions")
    func resizing() async {
        let model = ResizeEditorViewModel(item: file, format: nil, previews: FakePreviewProvider(image))
        await model.load()
        model.fitLongEdge(1280)
        #expect(model.width == 400 && model.height == 200)
        model.fitLongEdge(100)
        #expect(model.width == 100 && model.height == 50)
        model.percentage = 200
        model.applyPercentage()
        #expect(model.settings == .resize(width: 800, height: 400))
        model.reset()
        #expect(model.settings == .resize(width: 400, height: 200))
    }

    @Test("precise trim and bleep ranges reject invalid values before export")
    func timingValidation() async {
        let trim = TrimEditorViewModel(item: file, format: nil, previews: FakePreviewProvider(clip))
        await trim.load()
        trim.selectFraction(0.25, 0.75)
        #expect(trim.settings == .trim(start: 3, end: 9))
        trim.end = 13
        #expect(trim.settings == nil)
        trim.start = .nan
        #expect(trim.settings == nil)
        trim.reset()
        #expect(trim.settings == nil)
        let bleep = BleepEditorViewModel(item: file, format: nil, previews: FakePreviewProvider(clip))
        await bleep.load()
        bleep.addSpan()
        bleep.nextSelection()
        #expect(bleep.start == 1 && bleep.end == 2)
        bleep.start = -1
        #expect(!bleep.canAdd)
        bleep.clear()
        #expect(bleep.settings == nil)
    }

    @Test("custom cuts are sorted, separated and carried to the actual split request")
    func splitCuts() async {
        let model = SplitEditorViewModel(item: file, format: nil, previews: FakePreviewProvider(clip))
        await model.load()
        model.mode = .custom
        model.cutTime = 8
        model.addCut()
        model.cutTime = 3
        model.addCut()
        #expect(model.settings == .split(points: [3, 8]))
        #expect(model.outputCount == 3)
        model.cutTime = 3.01
        #expect(!model.canAddCut)
        model.cutTime = .infinity
        #expect(!model.canAddCut)
        model.removeCut(3)
        #expect(model.settings == .split(points: [8]))
    }

    @Test("last snapshot uses the backend's last-frame path and rejects nonfinite positions")
    func snapshotEnd() async {
        let model = SnapshotEditorViewModel(item: file, format: nil, previews: FakePreviewProvider(clip))
        await model.load()
        model.selectFraction(1)
        #expect(model.settings == .snapshot(at: 12))
        model.time = .nan
        #expect(model.settings == nil)
        #expect(TimeLabel.text(.infinity) == "–")
        #expect(TimeLabel.text(.nan) == "–")
    }

    @Test("rotate offers supported image flips and rejects PDF mirror settings")
    func rotateCapability() async {
        let pdf = FormatDescriptor(id: FormatID("pdf"), displayName: "PDF", extensions: ["pdf"], family: .document)
        let model = RotateEditorViewModel(item: file, format: pdf, previews: FakePreviewProvider(image))
        await model.load()
        #expect(!model.supportsMirroring)
        model.flipHorizontal = true
        #expect(model.settings == nil)
        model.reset()
        #expect(model.settings == nil)
        model.quarterTurns = 3
        #expect(model.outputSize?.width == 200 && model.outputSize?.height == 400)
        #expect(model.settings == .rotate(quarterTurns: 3, flipHorizontal: false, flipVertical: false))
    }

    @Test("redaction undo/redo and individual removal preserve real boxes")
    func redactionHistory() async {
        let model = RedactEditorViewModel(item: file, format: nil, previews: FakePreviewProvider(image))
        await model.load()
        model.begin(at: UnitPoint(x: 0.1, y: 0.1))
        model.move(to: UnitPoint(x: 0.5, y: 0.5))
        model.end()
        model.remove(at: 0)
        #expect(model.boxes.isEmpty)
        model.undo()
        #expect(model.boxes.count == 1)
        model.redo()
        #expect(model.settings == nil)
    }

    @Test("page range parsing supports Arabic digits and rejects partial invalid selection")
    func pageRanges() {
        #expect(PageRangeSelection.parse("١-٣، ٥", pageCount: 6) == Set([0, 1, 2, 4]))
        for text in ["0", "7", "3-1", "1-", "1,,2", "1,99", "", "-2"] {
            #expect(PageRangeSelection.parse(text, pageCount: 6) == nil)
        }
    }

    @Test("page shortcuts and invalid ranges retain the previous valid selection")
    func pageSelection() async {
        let previews = FakePreviewProvider(.empty, pages: Array(repeating: Data([1]), count: 6))
        let model = ExtractPagesEditorViewModel(item: file, previews: previews)
        await model.load()
        model.selectOdd()
        #expect(model.settings == .pages([0, 2, 4]))
        model.invert()
        #expect(model.settings == .pages([1, 3, 5]))
        model.rangeText = "99"
        model.applyRange()
        #expect(model.rangeInvalid && model.selected == Set([1, 3, 5]))
        let order = ReorganizePagesEditorViewModel(item: file, previews: previews)
        await order.load()
        order.reverse()
        order.move(from: IndexSet(integer: 99), to: 999)
        #expect(order.order == [5, 4, 3, 2, 1, 0])
        order.movePage(5, by: 1)
        #expect(order.order.prefix(2) == [4, 5])
    }

    @Test("metadata restore and clear produce only real changed fields")
    func metadataRestore() async {
        let model = MetadataEditorViewModel(item: file, format: nil,
                                            reader: StubMetadataReader([.title: "Original", .author: "Author"]))
        await model.load()
        model.clear()
        #expect(model.changes == [.title: "", .author: ""])
        model.restore()
        #expect(model.settings == nil)
    }

    @Test("collage layouts and background compositions use export settings")
    func compositions() async {
        let previews = FakePreviewProvider(image)
        let collage = CollageEditorViewModel(items: [file, file, file], formats: [nil, nil, nil], previews: previews)
        collage.applyLayout(2)
        #expect(collage.columns == 1 && collage.rows == 3)
        collage.reset()
        #expect(collage.columns == 2 && collage.rows == 2)
        let background = AddBackgroundEditorViewModel(item: file, format: nil, previews: previews)
        await background.load()
        background.applyComposition(2)
        #expect(background.style.padding == 0.22 && background.style.shadow == 50)
        background.update { $0.ratio = .threeTwo }
        #expect(abs(background.canvasAspectRatio - 1.5) < 0.02)
    }

    @Test("malformed durations and tiny clips do not enable invalid operations")
    func malformedDurations() async {
        let invalid = ToolPreview(width: nil, height: nil, duration: .nan, pageCount: nil, thumbnail: nil)
        let trim = TrimEditorViewModel(item: file, format: nil, previews: FakePreviewProvider(invalid))
        await trim.load()
        #expect(trim.duration == 0 && trim.settings == nil)
        let tiny = ToolPreview(width: nil, height: nil, duration: 0.08, pageCount: nil, thumbnail: nil)
        let split = SplitEditorViewModel(item: file, format: nil, previews: FakePreviewProvider(tiny))
        await split.load()
        #expect(split.settings == nil)
    }
}
