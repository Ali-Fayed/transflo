import Testing
import TransfloDomain

@Suite("HotKey")
struct HotKeyTests {
    @Test("the default is Option-Command-Return")
    func standard() {
        #expect(HotKey.standard == HotKey(keyCode: 36, modifiers: [.option, .command]))
        #expect(HotKey.standard.isValid)
    }

    @Test("a shortcut needs Command, Option or Control", arguments: [
        ([ModifierKey](), false), ([.shift], false), ([.shift, .control], true), ([.option], true), ([.command], true)
    ])
    func validity(modifiers: [ModifierKey], valid: Bool) {
        #expect(HotKey(keyCode: 49, modifiers: Set(modifiers)).isValid == valid)
    }
}
