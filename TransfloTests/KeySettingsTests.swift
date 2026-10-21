import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Settings › Keys")
struct KeySettingsTests {
    private let space = HotKey(keyCode: 49, modifiers: [.control, .option])

    private func makeSUT(_ repository: InMemoryInputPreferences = InMemoryInputPreferences(), applier: SpyInputApplier)
        -> KeySettingsViewModel {
        KeySettingsViewModel(repository: repository, applier: applier, installedTerminals: [.terminal, .warp])
    }

    @Test("giving a wheel another wheel's key swaps them, saves and applies")
    func assignKey() {
        let repository = InMemoryInputPreferences()
        let applier = SpyInputApplier()
        let sut = makeSUT(repository, applier: applier)
        sut.assign(.control, to: .convert)
        #expect(sut.key(for: .convert) == .control && sut.key(for: .actions) == .shift)
        #expect(repository.load().wheelKeys == sut.preferences.wheelKeys)
        #expect(applier.applied.map(\.wheelKeys) == [sut.preferences.wheelKeys])
        sut.assign(.control, to: .convert)
        #expect(applier.applied.count == 1)
    }

    @Test("a recorded shortcut is saved, applied and shown")
    func recordShortcut() {
        let repository = InMemoryInputPreferences()
        let applier = SpyInputApplier()
        let sut = makeSUT(repository, applier: applier)
        #expect(sut.shortcutText == "⌥⌘↩")
        sut.record(keyCode: 49, modifiers: [.control, .option])
        #expect(repository.load().hotKey == space && sut.shortcutText == "⌃⌥Space")
        #expect(sut.shortcutMessage == nil)
    }

    @Test("a shortcut without ⌘, ⌥ or ⌃ is refused before reaching the system")
    func invalidShortcut() {
        let applier = SpyInputApplier()
        let sut = makeSUT(applier: applier)
        sut.record(keyCode: 0, modifiers: [.shift])
        #expect(sut.shortcutMessage == .shortcutInvalid)
        #expect(sut.preferences.hotKey == .standard && applier.applied.isEmpty)
    }

    @Test("a shortcut another app owns is rolled back to the old one")
    func takenShortcut() {
        let repository = InMemoryInputPreferences()
        let applier = SpyInputApplier()
        applier.taken = [space]
        let sut = makeSUT(repository, applier: applier)
        sut.record(keyCode: 49, modifiers: [.control, .option])
        #expect(sut.shortcutMessage == .shortcutTaken)
        #expect(sut.preferences.hotKey == .standard && repository.load().hotKey == .standard)
        #expect(applier.applied.last?.hotKey == .standard)
    }

    @Test("the terminal choice is saved")
    func terminal() {
        let repository = InMemoryInputPreferences()
        let sut = makeSUT(repository, applier: SpyInputApplier())
        sut.selectTerminal(.warp)
        #expect(repository.load().terminal == .warp && sut.installedTerminals == [.terminal, .warp])
    }

    @Test("shortcut text follows macOS menu order", arguments: [
        (HotKey(keyCode: 36, modifiers: [.command, .option]), "⌥⌘↩"),
        (HotKey(keyCode: 0, modifiers: [.command, .shift, .control, .option]), "⌃⌥⇧⌘A"),
        (HotKey(keyCode: 122, modifiers: [.control]), "⌃F1"),
        (HotKey(keyCode: 999, modifiers: [.command]), "⌘#999")
    ])
    func formatting(hotKey: HotKey, text: String) {
        #expect(HotKeyFormatter.text(hotKey) == text)
    }

    @Test("the wheel hub follows rebinding")
    func hubGlyph() {
        let sut = WheelViewModel(bindings: .standard, layout: StubLayoutDirection(),
                                 sizing: .fixed(innerRadius: 50, outerRadius: 150))
        sut.show(.convert, options: [WheelOption(.action(.copy))])
        let before = sut.hubGlyph
        sut.update(bindings: WheelKeyBindings.standard.assigning(.option, to: .convert))
        #expect(before == "⇧" && sut.hubGlyph == "⌥")
        #expect(sut.wheel(for: .option) == .convert)
    }
}
