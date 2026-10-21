import Carbon.HIToolbox
import Testing
import TransfloDomain
@testable import TransfloSystem

@Suite("Carbon hot keys")
struct CarbonHotKeyCenterTests {
    @Test("modifiers map to Carbon's masks")
    func masks() {
        #expect(CarbonHotKeyCenter.carbonModifiers([.option, .command]) == UInt32(optionKey | cmdKey))
        #expect(CarbonHotKeyCenter.carbonModifiers([.control, .shift]) == UInt32(controlKey | shiftKey))
        #expect(CarbonHotKeyCenter.carbonModifiers([]) == 0)
    }

    @Test("invalid shortcuts are refused before reaching the system")
    @MainActor
    func refusesInvalid() {
        let sut = CarbonHotKeyCenter()
        #expect(!sut.register(HotKey(keyCode: 49, modifiers: [.shift])) {})
        sut.unregister()
    }
}
