import Foundation
import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Tool editors")
struct ToolEditorTests {
    private let file = URL(fileURLWithPath: "/tmp/clip.mp4")
    private let image = ToolPreview(width: 400, height: 200, duration: nil, pageCount: nil, thumbnail: Data("t".utf8))
    private let clip = ToolPreview(width: 128, height: 96, duration: 10, pageCount: nil, thumbnail: Data("t".utf8))

    @Test("resize keeps proportions, scales presets, and validates sizes")
    func resize() async {
        let sut = ResizeEditorViewModel(item: file, format: nil, previews: FakePreviewProvider(image))
        #expect(sut.settings == nil)
        await sut.load()
        #expect(sut.settings == .resize(width: 400, height: 200))
        sut.setWidth(100)
        #expect(sut.height == 50)
        sut.keepsProportions = false
        sut.setHeight(70)
        #expect(sut.width == 100)
        sut.scale(25)
        #expect(sut.settings == .resize(width: 100, height: 50))
        #expect(!sut.keepsProportions)
        sut.setWidth(0)
        #expect(sut.settings == nil)
    }

    @Test("crop presets center the largest box of that shape and keep it while dragging")
    func crop() async {
        let sut = CropEditorViewModel(item: file, format: nil, previews: FakePreviewProvider(image))
        await sut.load()
        #expect(sut.settings == nil)
        sut.select(.square)
        #expect(sut.rect == NormalizedRect(x: 0.25, y: 0, width: 0.5, height: 1))
        sut.propose(NormalizedRect(x: 0, y: 0, width: 0.25, height: 0.9))
        #expect(sut.rect.height == 0.5)
        sut.select(.free)
        sut.propose(NormalizedRect(x: 0.1, y: 0.1, width: 0.3, height: 0.2))
        #expect(sut.settings == .crop(NormalizedRect(x: 0.1, y: 0.1, width: 0.3, height: 0.2)))
    }

    private func close(_ lhs: NormalizedRect, _ rhs: NormalizedRect) -> Bool {
        [lhs.x - rhs.x, lhs.y - rhs.y, lhs.width - rhs.width, lhs.height - rhs.height].allSatisfy { abs($0) < 1e-9 }
    }

    @Test("crop box math moves and resizes from corners")
    func cropGeometry() {
        let start = NormalizedRect(x: 0.2, y: 0.2, width: 0.4, height: 0.4)
        #expect(close(CropGeometry.proposal(from: start, corner: nil, deltaX: 0.1, deltaY: -0.1),
                      NormalizedRect(x: 0.3, y: 0.1, width: 0.4, height: 0.4)))
        #expect(close(CropGeometry.proposal(from: start, corner: .bottomTrailing, deltaX: 0.1, deltaY: 0.1),
                      NormalizedRect(x: 0.2, y: 0.2, width: 0.5, height: 0.5)))
        // Dragging a corner past its opposite edge flips the box instead of inverting it.
        #expect(close(CropGeometry.proposal(from: start, corner: .topLeading, deltaX: 0.5, deltaY: 0),
                      NormalizedRect(x: 0.6, y: 0.2, width: 0.1, height: 0.4)))
    }

    @Test("adjust is applicable only when changed, and previews the current sliders")
    func adjust() async {
        let previews = FakePreviewProvider(image)
        let sut = AdjustEditorViewModel(item: file, format: nil, previews: previews)
        await sut.load()
        #expect(sut.settings == nil)
        sut.exposure = 1
        await sut.refreshPreview()
        #expect(sut.adjustedThumbnail == Data("adjusted".utf8))
        #expect(previews.requestedAdjustments == [ImageAdjustments(exposure: 1, contrast: 1, saturation: 1)])
        #expect(sut.settings == .adjust(ImageAdjustments(exposure: 1, contrast: 1, saturation: 1)))
        sut.reset()
        #expect(sut.settings == nil)
    }

    @Test("trim needs a real cut of at least a tenth of a second")
    func trim() async {
        let sut = TrimEditorViewModel(item: file, format: nil, previews: FakePreviewProvider(clip))
        await sut.load()
        #expect(sut.end == 10)
        #expect(sut.settings == nil)
        sut.start = 2
        #expect(sut.settings == .trim(start: 2, end: 10))
        sut.end = 2.05
        #expect(sut.settings == nil)
    }

    @Test("speed shows the new length and rejects no-ops")
    func speed() async {
        let sut = SpeedEditorViewModel(item: file, format: nil, previews: FakePreviewProvider(clip))
        await sut.load()
        #expect(sut.newDuration == 5)
        #expect(sut.settings == .changeSpeed(2))
        sut.factor = 1.0001
        #expect(sut.settings == nil)
    }

    @Test("split cuts media into equal parts and PDFs into page groups")
    func split() async {
        let media = SplitEditorViewModel(item: file, format: nil, previews: FakePreviewProvider(clip))
        await media.load()
        media.parts = 4
        #expect(media.settings == .split(points: [2.5, 5, 7.5]))
        let pdf = FormatDescriptor(id: FormatID("pdf"), displayName: "PDF", extensions: ["pdf"], family: .document)
        let document = ToolPreview(width: nil, height: nil, duration: nil, pageCount: 6, thumbnail: nil)
        let pages = SplitEditorViewModel(item: file, format: pdf, previews: FakePreviewProvider(document))
        await pages.load()
        #expect(pages.pageRange == 1...5)
        pages.pagesPerFile = 2
        #expect(pages.settings == .splitPages(every: 2))
        pages.pagesPerFile = 6
        #expect(pages.settings == nil)
    }

    @Test("snapshot fetches the frame at the chosen time")
    func snapshot() async {
        let previews = FakePreviewProvider(clip)
        let sut = SnapshotEditorViewModel(item: file, format: nil, previews: previews)
        await sut.load()
        sut.time = 4
        await sut.refreshFrame()
        #expect(previews.requestedFrames == [4])
        #expect(sut.frame == Data("frame 4.0".utf8))
        #expect(sut.settings == .snapshot(at: 4))
    }

    @Test("time labels read naturally",
          arguments: [(0.0, "0:00.0"), (5.34, "0:05.3"), (725, "12:05.0"), (3723.5, "1:02:03.5")])
    func timeLabels(seconds: Double, text: String) {
        #expect(TimeLabel.text(seconds) == text)
    }

    @Test("the coordinator offers an editor for every interactive tool and none without files")
    func coordinator() {
        let sut = ToolEditorCoordinator(
            formats: CatalogFixtures.catalog,
            previews: FakePreviewProvider(clip),
            metadata: StubMetadataReader(),
            localizer: Localizer(language: .english)
        )
        #expect(ToolEditorCoordinator.editableTools.count == 26)
        for tool in ToolKind.allCases {
            #expect(sut.canEdit(tool) == ToolEditorCoordinator.editableTools.contains(tool))
            #expect((sut.makeSession(tool, items: [file, file]) != nil) == sut.canEdit(tool))
            #expect(sut.makeSession(tool, items: []) == nil)
        }
    }
    @Test("portrait crop ratios fit both image orientations and pixel edits keep the ratio")
    func portraitCropRatiosAndPixels() async {
        for dimensions in [(400, 200), (200, 400)] {
            let preview = ToolPreview(width: dimensions.0, height: dimensions.1, duration: nil,
                                      pageCount: nil, thumbnail: Data([1]))
            let model = CropEditorViewModel(item: file, format: nil, previews: FakePreviewProvider(preview))
            await model.load()
            for aspect in [CropAspect.nineSixteen, .threeFour, .fourFive] {
                model.select(aspect)
                let ratio = Double(model.pixelWidth) / Double(model.pixelHeight)
                #expect(abs(ratio - (aspect.ratio(imageWidth: dimensions.0, imageHeight: dimensions.1) ?? 0)) < 0.01)
                #expect(model.pixelWidth <= dimensions.0 && model.pixelHeight <= dimensions.1)
            }
            model.select(.square)
            model.setWidth(100)
            #expect(model.pixelWidth == 100 && model.pixelHeight == 100)
            model.setHeight(50)
            #expect(model.pixelWidth == 50 && model.pixelHeight == 50)
            model.setWidth(100_000)
            #expect(model.pixelWidth == min(dimensions.0, dimensions.1))
            let previous = model.rect
            model.setWidth(0)
            model.setHeight(-2)
            #expect(model.rect == previous)
            model.reset()
            #expect(model.aspect == .free && model.rect == .full && model.settings == nil)
            model.setWidth(1)
            #expect(model.pixelWidth == 1)
        }
    }

    @Test("missing and cancelled crop previews cannot produce settings")
    func invalidCropPreview() async {
        let missing = ToolPreview(width: 400, height: 200, duration: nil, pageCount: nil, thumbnail: nil)
        let model = CropEditorViewModel(item: file, format: nil, previews: FakePreviewProvider(missing))
        await model.load()
        model.select(.square)
        #expect(model.settings == nil)
        let cancelled = CropEditorViewModel(item: file, format: nil, previews: FakePreviewProvider(image))
        let task = Task { await cancelled.load() }
        task.cancel()
        await task.value
        #expect(cancelled.preview == .empty)
    }
}
