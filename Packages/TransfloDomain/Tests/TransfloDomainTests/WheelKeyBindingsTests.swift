import Testing
import TransfloDomain

@Suite("Wheel key bindings")
struct WheelKeyBindingsTests {
    @Test("taking another wheel's key swaps the two")
    func swaps() {
        let sut = WheelKeyBindings.standard.assigning(.command, to: .convert)
        #expect(sut.key(for: .convert) == .command)
        #expect(sut.key(for: .tools) == .shift)
        #expect(sut.key(for: .actions) == .control)
    }

    @Test("a free key just moves the wheel, freeing its old key")
    func movesToFreeKey() {
        let sut = WheelKeyBindings.standard.assigning(.option, to: .actions)
        #expect(sut.key(for: .actions) == .option)
        #expect(sut.wheel(for: .control) == nil)
        #expect(sut.key(for: .convert) == .shift && sut.key(for: .tools) == .command)
    }

    @Test("re-assigning a wheel its own key changes nothing")
    func sameKey() {
        #expect(WheelKeyBindings.standard.assigning(.shift, to: .convert) == .standard)
    }
}
