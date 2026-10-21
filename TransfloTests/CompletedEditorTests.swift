import Foundation
import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Completed tool editors")
struct CompletedEditorTests {
    private let file = URL(fileURLWithPath: "/tmp/source.png")
    private var facts: ToolPreview {
        ToolPreview(width: 640, height: 480, duration: 10, pageCount: 3, thumbnail: Data([1]), frameRate: 25)
    }
    private var inspector: FakeToolInspector { FakeToolInspector() }

    @Test("assembly reorders, omits, resets, and carries page layout into the export settings")
    func assembly() async {
        let model = AssemblyEditorViewModel(items: [file, file, file], formats: Array(repeating: nil, count: 3),
            isPDFExport: true, previews: FakePreviewProvider(facts))
        #expect(model.settings == nil)
        await model.load()
        model.shift(2, by: -1)
        model.remove(0)
        model.paper = .letter; model.landscape = true; model.margin = 36; model.fill = true
        #expect(model.order == [2, 1])
        #expect(model.pageSize == CGSize(width: 792, height: 612))
        #expect(model.settings == .assemble(model.assembly))
        model.remove(1)
        #expect(model.settings == nil)
        model.reset()
        #expect(model.order == [0, 1, 2] && model.settings != nil)
        model.margin = .nan
        #expect(model.settings == nil)
    }

    @Test("background removal cannot export a stale preview")
    func background() async {
        let model = BackgroundRemovalEditorViewModel(item: file, format: nil,
            previews: FakePreviewProvider(facts), inspector: inspector)
        await model.load()
        #expect(model.settings == .removeBackground(BackgroundRemovalSettings()))
        model.options.subject = 2
        model.options.feather = 0.01
        #expect(model.settings == nil)
        await model.refresh()
        #expect(model.settings == .removeBackground(model.requested))
        model.solidBackground = true
        #expect(model.settings == nil)
        await model.refresh()
        #expect(model.requested.background == "#F2F5F4" && model.settings != nil)
    }

    @Test("audio controls carry targets, reject invalid values and invalidate processed audition")
    func audio() async {
        let model = AudioToolEditorViewModel(item: file, format: nil, tool: .normalize,
            previews: FakePreviewProvider(facts), inspector: inspector)
        await model.load()
        model.preset(2)
        #expect(model.settings == .normalize(LoudnessSettings(integrated: -23, truePeak: -1, range: 7)))
        await model.prepareAudition()
        #expect(model.currentAudition != nil)
        model.targets.integrated = -18
        #expect(model.currentAudition == nil)
        model.targets.truePeak = .infinity
        #expect(model.settings == nil)
        let channels = AudioToolEditorViewModel(item: file, format: nil, tool: .channels,
            previews: FakePreviewProvider(facts), inspector: inspector)
        await channels.load(); channels.mix = .right
        #expect(channels.settings == .channels(.right))
    }

    @Test("QR results are selectable and only explicit HTTP(S) URLs can be opened")
    func codes() async {
        let model = CodeResultsViewModel(items: [file], inspector: inspector)
        await model.load()
        #expect(model.settings == .copyCodes(["https://example.com/", "plain text"]))
        model.toggle(1)
        #expect(model.settings == .copyCodes(["https://example.com/"]))
        model.selectNone()
        #expect(model.settings == nil)
        #expect(model.webURL("javascript:alert(1)") == nil)
        #expect(model.webURL("file:///etc/passwd") == nil)
        #expect(model.webURL("https://example.com/") != nil)
    }

    @Test("metadata inspection includes every source and selection is explicit")
    func metadata() async {
        let model = MetadataRemovalEditorViewModel(items: [file, file], inspector: inspector)
        await model.load()
        #expect(model.sources.count == 2 && model.removalCount == 4)
        model.selected = [.location]
        #expect(model.settings == .removeMetadata([.location]) && model.removalCount == 2)
        model.selected = []
        #expect(model.settings == nil)
    }

    @Test("PDF annotations keep page edits and undo histories separate")
    func pdfAnnotations() async {
        let pdf = FormatDescriptor(id: FormatID("pdf"), displayName: "PDF", extensions: ["pdf"], family: .document)
        let model = AnnotateEditorViewModel(item: file, format: pdf,
            previews: FakePreviewProvider(facts, pages: [Data([1]), Data([2]), Data([3])]))
        await model.load()
        model.tool = .text; model.text = "First"
        model.begin(at: UnitPoint(x: 0.1, y: 0.1))
        await model.selectPage(2)
        model.text = "Third"; model.begin(at: UnitPoint(x: 0.2, y: 0.2))
        #expect(model.editedPageCount == 2)
        model.undo()
        #expect(model.editedPageCount == 1)
        await model.selectPage(0)
        #expect(model.annotations.count == 1 && model.canUndo && !model.canRedo)
        guard case .pageAnnotations(let pages) = model.settings else { Issue.record("Missing page settings"); return }
        #expect(Set(pages.keys) == [0])
    }

    @Test("PDF redaction keeps regions on their original pages")
    func pdfRedactions() async {
        let pdf = FormatDescriptor(id: FormatID("pdf"), displayName: "PDF", extensions: ["pdf"], family: .document)
        let model = RedactEditorViewModel(item: file, format: pdf,
            previews: FakePreviewProvider(facts, pages: [Data([1]), Data([2]), Data([3])]))
        await model.load()
        model.begin(at: UnitPoint(x: 0.1, y: 0.1)); model.move(to: UnitPoint(x: 0.4, y: 0.4)); model.end()
        await model.selectPage(1)
        #expect(model.boxes.isEmpty)
        model.begin(at: UnitPoint(x: 0.2, y: 0.2)); model.move(to: UnitPoint(x: 0.8, y: 0.8)); model.end()
        guard case .pageRedactions(let pages) = model.settings else { Issue.record("Missing page redactions"); return }
        #expect(Set(pages.keys) == [0, 1])
        #expect(pages[0]?.first?.x == 0.1 && pages[1]?.first?.x == 0.2)
    }

    @Test("collage ordering and sizing invalidate the composed preview until rendered")
    func collage() async {
        let model = CollageEditorViewModel(items: [file, file, file], formats: [nil, nil, nil],
            previews: FakePreviewProvider(facts), inspector: inspector)
        await model.load()
        #expect(model.settings == .collageLayout(model.layoutSettings))
        model.shift(2, by: -1); model.cellWidth = 300; model.fill = true
        #expect(model.settings == nil)
        await model.renderPreview()
        #expect(model.order == [0, 2, 1] && model.settings != nil)
    }

    @Test("snapshot frame steps use probed rate and JPEG quality reaches export")
    func snapshot() async {
        let model = SnapshotEditorViewModel(item: file, format: nil, previews: FakePreviewProvider(facts))
        await model.load()
        model.stepFrame(1)
        #expect(abs(model.time - 0.04) < 0.00001)
        model.jpeg = true; model.quality = 85
        #expect(model.settings == .snapshotJPEG(at: 0.04, quality: 85))
    }
}
