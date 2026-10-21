import CoreGraphics
import Testing
@testable import Transflo

@Suite("Window placement on small screens")
struct WindowPlacementTests {
    /// A 1024 × 768 display with the menu bar and Dock taken out.
    private let visible = CGRect(x: 0, y: 80, width: 1024, height: 658)

    @Test("a window already inside the visible area stays where it is")
    func insideUnchanged() {
        let frame = CGRect(x: 100, y: 200, width: 600, height: 400)
        #expect(WindowPlacement.fitted(frame, in: visible) == frame)
    }

    @Test("a window grown past the right edge moves left, keeping its size")
    func pastRightEdge() {
        let frame = CGRect(x: 512, y: 200, width: 700, height: 400)
        #expect(WindowPlacement.fitted(frame, in: visible) == CGRect(x: 324, y: 200, width: 700, height: 400))
    }

    @Test("a window below the Dock or under the menu bar moves back inside",
          arguments: [CGRect(x: 10, y: 20, width: 600, height: 400), CGRect(x: 10, y: 500, width: 600, height: 400)])
    func verticalEdges(frame: CGRect) {
        let fitted = WindowPlacement.fitted(frame, in: visible)
        #expect(fitted.minY >= visible.minY)
        #expect(fitted.maxY <= visible.maxY)
        #expect(fitted.size == frame.size)
    }

    @Test("a window larger than the screen shrinks to it")
    func largerThanScreen() {
        let frame = CGRect(x: -50, y: 0, width: 1400, height: 900)
        #expect(WindowPlacement.fitted(frame, in: visible) == visible)
    }

    @Test("centering uses the window's measured size, not its size at creation")
    func centered() {
        let frame = WindowPlacement.centered(CGSize(width: 860, height: 600), in: visible)
        #expect(frame == CGRect(x: 82, y: 109, width: 860, height: 600))
    }

    @Test("centering a window taller than the screen pins it to the visible area")
    func centeredTooTall() {
        let frame = WindowPlacement.centered(CGSize(width: 700, height: 900), in: visible)
        #expect(frame == CGRect(x: 162, y: 80, width: 700, height: 658))
    }
}
