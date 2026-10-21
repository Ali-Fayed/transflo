import CoreGraphics
import Testing
import TransfloDomain
@testable import TransfloMobile

@Suite("Mobile wheel")
struct MobileWheelTests {
    @Test("the presenter shows and hides, and forwards taps and touches as offsets")
    func presenter() {
        // Given a presenter wired like the coordinator wires it
        let sut = MobileWheelPresenter()
        var clicks: [WheelPoint] = [], touches: [WheelPoint] = []
        sut.onClick = { clicks.append($0); return true }
        sut.onPointer = { touches.append($0) }
        // When it opens, is touched and tapped, then closes
        sut.showInteractive(at: WheelPoint(x: 5, y: 5))
        #expect(sut.isShown)
        sut.touch(at: WheelPoint(x: 1, y: 2))
        #expect(sut.tap(at: WheelPoint(x: 3, y: -4)))
        sut.hide()
        // Then the offsets reached the coordinator and the wheel is gone
        #expect(touches == [WheelPoint(x: 1, y: 2)] && clicks == [WheelPoint(x: 3, y: -4)])
        #expect(!sut.isShown)
    }

    @Test("a tap with no coordinator attached hits nothing")
    func unattached() {
        #expect(!MobileWheelPresenter().tap(at: WheelPoint(x: 0, y: 0)))
    }

    @Test("search exposes every matching option without wheel pagination")
    func search() {
        let localizer = Localizer(language: .english)
        let options = (0..<40).map {
            WheelOption(.format(FormatDescriptor(id: FormatID("format-\($0)"), displayName: "Format \($0)",
                                                 extensions: ["f\($0)"], family: .image)))
        }
        #expect(MobileActionPresentation.filtered(options, query: "", localizer: localizer).count == 40)
        #expect(MobileActionPresentation.filtered(options, query: "Format 39", localizer: localizer) == [options[39]])
        #expect(MobileActionPresentation.filtered(options, query: "unsupported", localizer: localizer).isEmpty)
    }
}
