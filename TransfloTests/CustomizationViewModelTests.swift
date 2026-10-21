import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Customization")
struct CustomizationViewModelTests {
    @Test("changes persist and apply to the shared presentation state")
    func saveAndApply() {
        let repository = FakeSettingsRepository()
        let style = InterfaceStyle()
        let sut = CustomizationViewModel(repository: repository, style: style)
        sut.update {
            $0.accentHex = "7c3aed"
            $0.wheelSize = .large
            $0.solidSurfaces = true
            $0.reduceMotion = true
        }
        #expect(repository.loadCustomization() == sut.preferences)
        #expect(style.preferences == sut.preferences)
        #expect(sut.preferences.accentHex == "7C3AED")
        let reopened = CustomizationViewModel(repository: repository, style: style)
        #expect(reopened.preferences == sut.preferences)
        sut.reset()
        #expect(repository.loadCustomization() == .standard)
        #expect(style.preferences == .standard)
    }

    @Test("wheel scale changes the hit-test geometry along with the rendered wheel")
    func scaledGeometry() {
        let options = ActionKind.allCases.map { WheelOption(.action($0)) }
        let standard = WheelViewModel(bindings: .standard, layout: StubLayoutDirection(isRightToLeft: false))
        let enlarged = WheelViewModel(
            bindings: .standard,
            layout: StubLayoutDirection(isRightToLeft: false),
            sizingProvider: { .standard.scaled(by: InterfaceCustomization.WheelSize.large.scale) }
        )
        standard.show(.actions, options: options)
        enlarged.show(.actions, options: options)
        let point = WheelPoint(x: 160, y: 0)
        #expect(standard.option(at: point) == nil)
        #expect(enlarged.option(at: point) != nil)
    }
}
