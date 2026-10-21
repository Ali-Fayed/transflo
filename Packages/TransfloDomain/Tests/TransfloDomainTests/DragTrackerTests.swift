import Testing
import TransfloDomain

@Suite("DragTracker")
struct DragTrackerTests {
    private static let origin = WheelPoint(x: 0, y: 0)

    private func sample(
        down: Bool = true,
        count: Int = 1,
        keys: Set<ModifierKey> = [],
        at point: WheelPoint = origin
    ) -> DragSample {
        DragSample(isMouseDown: down, pasteboardChangeCount: count, modifiers: keys, location: point)
    }

    /// Mouse down at change count 1, then the pasteboard changes to 2: a drag began.
    private func draggingTracker(initialKeys: Set<ModifierKey> = []) -> DragTracker {
        var tracker = DragTracker(bindings: .standard)
        _ = tracker.process(sample(count: 1))
        let began = tracker.process(sample(count: 2, keys: initialKeys))
        precondition(began == [.began], "fixture must begin a drag")
        return tracker
    }

    @Test("a pasteboard change while the mouse is down begins a drag")
    func beginsDrag() {
        var sut = DragTracker(bindings: .standard)
        #expect(sut.process(sample(count: 5)).isEmpty)
        #expect(sut.process(sample(count: 5)).isEmpty)
        #expect(sut.process(sample(count: 6)) == [.began])
    }

    @Test("a click without a drag produces nothing")
    func clickIsIgnored() {
        var sut = DragTracker(bindings: .standard)
        #expect(sut.process(sample(count: 3)).isEmpty)
        #expect(sut.process(sample(down: false, count: 3)).isEmpty)
    }

    @Test("pressing a bound key mid-drag requests its wheel at the pointer", arguments: [
        (ModifierKey.shift, WheelKind.convert), (.command, .tools), (.control, .actions)
    ])
    func requestsWheel(key: ModifierKey, wheel: WheelKind) {
        var sut = draggingTracker()
        let point = WheelPoint(x: 40, y: 90)
        #expect(sut.process(sample(count: 2, keys: [key], at: point)) == [.wheelRequested(wheel, at: point)])
    }

    @Test("holding the key produces a single request; releasing produces nothing")
    func holdAndRelease() {
        var sut = draggingTracker()
        #expect(sut.process(sample(count: 2, keys: [.shift])).count == 1)
        #expect(sut.process(sample(count: 2, keys: [.shift])).isEmpty)
        #expect(sut.process(sample(count: 2, keys: [])).isEmpty)
    }

    @Test("tapping again after releasing requests the wheel again")
    func tapAgain() {
        var sut = draggingTracker()
        _ = sut.process(sample(count: 2, keys: [.shift]))
        _ = sut.process(sample(count: 2, keys: []))
        #expect(sut.process(sample(count: 2, keys: [.shift])) == [.wheelRequested(.convert, at: Self.origin)])
    }

    @Test("a key held before the drag began does nothing until pressed again")
    func heldBeforeDrag() {
        var sut = draggingTracker(initialKeys: [.command])
        #expect(sut.process(sample(count: 2, keys: [.command])).isEmpty)
        _ = sut.process(sample(count: 2, keys: []))
        #expect(sut.process(sample(count: 2, keys: [.command])) == [.wheelRequested(.tools, at: Self.origin)])
    }

    @Test("adding a second key while one is held switches to the second wheel")
    func switchesWheel() {
        var sut = draggingTracker()
        _ = sut.process(sample(count: 2, keys: [.shift]))
        #expect(sut.process(sample(count: 2, keys: [.shift, .control])) == [.wheelRequested(.actions, at: Self.origin)])
    }

    @Test("two keys pressed in the same sample resolve by priority")
    func simultaneousKeys() {
        var sut = draggingTracker()
        #expect(sut.process(sample(count: 2, keys: [.control, .shift])) == [.wheelRequested(.convert, at: Self.origin)])
    }

    @Test("an unbound key does nothing")
    func unboundKey() {
        var sut = draggingTracker()
        #expect(sut.process(sample(count: 2, keys: [.option])).isEmpty)
    }

    @Test("releasing the mouse ends the drag once")
    func endsDrag() {
        var sut = draggingTracker()
        #expect(sut.process(sample(down: false, count: 2)) == [.ended])
        #expect(sut.process(sample(down: false, count: 2)).isEmpty)
    }

    @Test("an ignored drag requests no wheels and does not report its end")
    func ignoredDrag() {
        var sut = draggingTracker()
        sut.ignoreCurrentDrag()
        #expect(sut.process(sample(count: 2, keys: [.shift])).isEmpty)
        #expect(sut.process(sample(down: false, count: 2)).isEmpty)
    }

    @Test("ignoring outside a drag has no effect on the next drag")
    func ignoreWhenIdle() {
        var sut = DragTracker(bindings: .standard)
        sut.ignoreCurrentDrag()
        _ = sut.process(sample(count: 1))
        #expect(sut.process(sample(count: 2)) == [.began])
    }

    @Test("custom bindings are honored")
    func customBindings() {
        var sut = DragTracker(bindings: WheelKeyBindings([.option: .convert]))
        _ = sut.process(sample(count: 1))
        _ = sut.process(sample(count: 2))
        #expect(sut.process(sample(count: 2, keys: [.shift])).isEmpty)
        #expect(sut.process(sample(count: 2, keys: [.shift, .option])) == [.wheelRequested(.convert, at: Self.origin)])
    }

    @Test("standard bindings map both ways")
    func standardBindings() {
        #expect(WheelKeyBindings.standard.key(for: .convert) == .shift)
        #expect(WheelKeyBindings.standard.key(for: .tools) == .command)
        #expect(WheelKeyBindings.standard.key(for: .actions) == .control)
        #expect(WheelKeyBindings([:]).key(for: .convert) == nil)
    }
}
