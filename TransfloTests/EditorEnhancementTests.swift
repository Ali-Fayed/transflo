import Foundation
import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Editor and feedback enhancements")
struct EditorEnhancementTests {
    private let file = URL(fileURLWithPath: "/tmp/portrait.png")

    @Test("compression offers the three presets for every type; an old size budget opens as a preset")
    func presetsOnly() async {
        let model = CompressEditorViewModel(items: [file, file], formats: [CatalogFixtures.png, CatalogFixtures.png],
                                            initialGoal: .percentage(40), size: { _ in 2_000_000 })
        #expect(model.settings == nil)
        await model.load()
        #expect(model.originalBytes == 4_000_000 && model.level == .medium)
        #expect(model.settings == .compress(.medium))
        model.level = .strong
        #expect(model.settings == .compress(.strong))
    }

    @Test("PDF uses the same presets and its own hint")
    func pdfCompression() async {
        let pdf = FormatDescriptor(id: FormatID("pdf"), displayName: "PDF", extensions: ["pdf"], family: .document)
        let model = CompressEditorViewModel(items: [file], formats: [pdf], initialGoal: .light,
                                            size: { _ in 1_000_000 })
        await model.load()
        #expect(model.isPDF && model.settings == .compress(.light))
    }

    @Test("an unreadable source size still compresses, without showing a size")
    func unknownSize() async {
        let model = CompressEditorViewModel(items: [file], formats: [CatalogFixtures.png], size: { _ in nil })
        await model.load()
        #expect(model.originalBytes == nil && model.settings == .compress(.medium))
    }

    @Test("original comparison changes only the preview; reset restores every adjustment")
    func photoComparisonAndReset() async {
        let original = Data("original".utf8)
        let preview = ToolPreview(width: 100, height: 80, duration: nil, pageCount: nil, thumbnail: original)
        let provider = FakePreviewProvider(preview)
        let model = AdjustEditorViewModel(item: file, format: CatalogFixtures.png, previews: provider)
        await model.load()
        model.values.brightness = 0.2
        model.values.vibrance = 0.4
        model.values.vignette = 0.5
        await model.refreshPreview()
        let settings = model.settings
        #expect(model.displayedThumbnail == Data("adjusted".utf8))
        model.showOriginal = true
        #expect(model.displayedThumbnail == original && model.settings == settings)
        model.values.brightness = 0
        #expect(model.values.vibrance == 0.4)
        model.reset()
        #expect(model.values == .neutral && model.settings == nil)
        #expect(model.displayedThumbnail == original && !model.showOriginal)
    }

    @Test("hover feedback fires once on entering an option and never in the hub")
    func hoverFeedback() {
        var ticks = 0
        let model = WheelViewModel(bindings: .standard, layout: StubLayoutDirection(),
                                   sizing: .fixed(innerRadius: 50, outerRadius: 150),
                                   onSelectionChange: { ticks += 1 })
        model.show(.actions, options: ActionKind.allCases.map { WheelOption(.action($0)) })
        #expect(ticks == 0)
        model.updatePointer(WheelPoint(x: 0, y: 100))
        model.updatePointer(WheelPoint(x: 1, y: 100))
        #expect(ticks == 1)
        model.updatePointer(WheelPoint(x: 100, y: 0))
        #expect(ticks == 2)
        model.updatePointer(WheelPoint(x: 0, y: 0))
        model.updatePointer(nil)
        #expect(ticks == 2)
        model.reset()
        #expect(ticks == 2)
    }

    @Test("haptics are rate limited and react immediately to their preference")
    func hapticPreferenceAndThrottle() {
        var enabled = true
        var instant = ContinuousClock.now
        var ticks = 0
        let feedback = WheelHaptics(isEnabled: { enabled }, now: { instant },
                                    isSoundEnabled: { false }, perform: { ticks += 1 })
        feedback.selectionChanged()
        feedback.selectionChanged()
        #expect(ticks == 1)
        instant += .milliseconds(70)
        feedback.selectionChanged()
        #expect(ticks == 2)
        enabled = false
        instant += .seconds(1)
        feedback.selectionChanged()
        #expect(ticks == 2)
        enabled = true
        feedback.selectionChanged()
        #expect(ticks == 3)
    }

    @Test("sound and haptics are independent, throttled, and change live")
    func independentFeedback() {
        var sound = true
        var haptics = false
        var instant = ContinuousClock.now
        var sounds = 0
        var vibrations = 0
        let feedback = WheelHaptics(isEnabled: { haptics }, now: { instant },
                                    isSoundEnabled: { sound }, performSound: { sounds += 1 },
                                    perform: { vibrations += 1 })
        feedback.selectionChanged()
        feedback.selectionChanged()
        #expect(sounds == 1 && vibrations == 0)
        instant += .milliseconds(70)
        haptics = true
        feedback.selectionChanged()
        #expect(sounds == 2 && vibrations == 1)
        instant += .milliseconds(70)
        sound = false
        feedback.selectionChanged()
        #expect(sounds == 2 && vibrations == 2)
        instant += .milliseconds(70)
        haptics = false
        feedback.selectionChanged()
        #expect(sounds == 2 && vibrations == 2)
        sound = true
        feedback.selectionChanged()
        #expect(sounds == 3 && vibrations == 2)
    }

    @Test("keyboard feedback skips More and does not repeat on a single option")
    func keyboardFeedback() throws {
        var ticks = 0
        let model = WheelViewModel(bindings: .standard, layout: StubLayoutDirection(),
                                   onSelectionChange: { ticks += 1 })
        let option = WheelOption(.action(ActionKind.allCases[0]))
        model.show(.actions, options: [option])
        model.stepHighlight(clockwise: true)
        model.stepHighlight(clockwise: true)
        #expect(ticks == 1)
        let distinct = ToolKind.allCases.prefix(13).map { WheelOption(.tool($0)) }
        model.show(.convert, options: distinct)
        for _ in 0..<12 { model.stepHighlight(clockwise: true) }
        #expect(ticks == 12)
        let selected = try #require(model.state.highlightedIndex)
        #expect(model.state.slots[selected] == .more)
        model.reset()
        model.stepHighlight(clockwise: true)
        #expect(ticks == 12)
    }

    @Test("the tick audio is packaged with the application")
    func tickResource() throws {
        let url = try #require(Bundle.main.url(forResource: "WheelTick", withExtension: "wav"))
        let data = try Data(contentsOf: url)
        #expect(data.prefix(4) == Data("RIFF".utf8))
        #expect(data.count > 44)
    }

    @Test("legacy percentage defaults become Balanced")
    func percentagePreferences() {
        let preferences = InMemoryToolPreferences(goal: .percentage(35))
        let model = ToolPreferencesViewModel(repository: preferences)
        #expect(model.choice == .medium)
        #expect(preferences.loadCompressionGoal() == .medium)
    }
}
