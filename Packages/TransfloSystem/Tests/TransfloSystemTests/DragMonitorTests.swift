import Foundation
import Testing
import TransfloDomain
@testable import TransfloSystem

@MainActor
@Suite("DragMonitor")
struct DragMonitorTests {
    private let file = URL(fileURLWithPath: "/tmp/photo.heic")
    private let point = WheelPoint(x: 300, y: 200)

    private func sample(down: Bool = true, count: Int, keys: Set<ModifierKey> = []) -> DragSample {
        DragSample(isMouseDown: down, pasteboardChangeCount: count, modifiers: keys, location: point)
    }

    /// A started monitor wired to scripted doubles.
    @MainActor
    private struct Harness {
        let sut: DragMonitor
        let sampler: ScriptedDragSampler
        let ticker = ManualTicker()
        let mouseDown = ManualMouseDown()

        init(samples: [DragSample], files: [URL]) {
            sampler = ScriptedDragSampler(samples: samples, fileURLs: files)
            sut = DragMonitor(bindings: .standard, sampler: sampler, ticker: ticker, mouseDown: mouseDown)
            sut.start()
        }
    }

    /// Mouse-down, drag start, Shift tap, release.
    private var dragWithShiftTap: [DragSample] {
        [sample(count: 1), sample(count: 2), sample(count: 2, keys: [.shift]), sample(down: false, count: 2)]
    }

    private func collect(_ sut: DragMonitor) async -> [DragEvent] {
        sut.stop()
        var events: [DragEvent] = []
        for await event in sut.events {
            events.append(event)
        }
        return events
    }

    @Test("a file drag with a Shift tap emits began, wheel request and end")
    func fullDrag() async {
        // Given mouse-down, drag start, Shift tap, release
        let harness = Harness(samples: dragWithShiftTap, files: [file])
        // When
        harness.mouseDown.press()
        harness.ticker.fire(times: 3)
        // Then
        #expect(await collect(harness.sut) == [.began(items: [file]), .wheelRequested(.convert, at: point), .ended])
    }

    @Test("new key bindings apply to the next drag, never mid-drag")
    func rebinding() async {
        let harness = Harness(samples: dragWithShiftTap + dragWithShiftTap, files: [file])
        harness.mouseDown.press()
        harness.ticker.fire(times: 1)
        harness.sut.update(bindings: WheelKeyBindings.standard.assigning(.shift, to: .actions))
        harness.ticker.fire(times: 2)
        harness.mouseDown.press()
        harness.ticker.fire(times: 3)
        #expect(await collect(harness.sut) == [
            .began(items: [file]), .wheelRequested(.convert, at: point), .ended,
            .began(items: [file]), .wheelRequested(.actions, at: point), .ended
        ])
    }

    @Test("polling starts on mouse-down and stops on mouse-up")
    func pollingLifecycle() {
        let harness = Harness(samples: [sample(count: 1), sample(down: false, count: 1)], files: [])
        #expect(harness.ticker.isRunning == false)
        harness.mouseDown.press()
        #expect(harness.ticker.isRunning)
        #expect(harness.sampler.sampleCount == 1)
        harness.ticker.fire()
        #expect(harness.ticker.isRunning == false)
    }

    @Test("repeated mouse-downs while polling do not restart the ticker")
    func noDoubleStart() {
        let harness = Harness(samples: [sample(count: 1)], files: [])
        harness.mouseDown.press()
        harness.mouseDown.press()
        #expect(harness.ticker.startCount == 1)
    }

    @Test("a drag without files is ignored entirely")
    func nonFileDrag() async {
        let harness = Harness(samples: dragWithShiftTap, files: [])
        harness.mouseDown.press()
        harness.ticker.fire(times: 3)
        #expect(await collect(harness.sut).isEmpty)
    }

    @Test("stopping finishes the stream and stops the mouse observer")
    func stopFinishes() async {
        let harness = Harness(samples: [sample(count: 1)], files: [])
        #expect(await collect(harness.sut).isEmpty)
        #expect(harness.mouseDown.isStopped)
    }

    @Test("system modifier flags map to modifier keys")
    func modifierMapping() {
        #expect(SystemDragSampler.modifiers(from: [.shift, .command]) == [.shift, .command])
        #expect(SystemDragSampler.modifiers(from: [.control, .option, .capsLock]) == [.control, .option])
        #expect(SystemDragSampler.modifiers(from: []).isEmpty)
    }
}
