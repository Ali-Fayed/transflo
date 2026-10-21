/// Turns raw system samples into drag lifecycle events (State Machine pattern).
///
/// A drag is detected when the drag pasteboard changes while the mouse is down. Modifier
/// presses only count after the drag began, so a key already held when the drag starts
/// (e.g. Finder's own ⌘-to-move) never opens a wheel until it is pressed again.
public struct DragTracker: Sendable {
    private enum State: Sendable, Equatable {
        case idle
        case armed(baseline: Int)
        case dragging(pressed: Set<ModifierKey>)
        case ignored
    }

    private var state: State = .idle
    private let bindings: WheelKeyBindings

    public init(bindings: WheelKeyBindings) {
        self.bindings = bindings
    }

    /// Advances the state machine with one sample.
    public mutating func process(_ sample: DragSample) -> [DragTrackerOutput] {
        guard sample.isMouseDown else {
            defer { state = .idle }
            if case .dragging = state { return [.ended] }
            return []
        }
        switch state {
        case .idle:
            state = .armed(baseline: sample.pasteboardChangeCount)
            return []
        case .armed(let baseline):
            guard sample.pasteboardChangeCount != baseline else { return [] }
            state = .dragging(pressed: sample.modifiers)
            return [.began]
        case .dragging(let pressed):
            state = .dragging(pressed: sample.modifiers)
            return wheelRequest(newlyPressed: sample.modifiers.subtracting(pressed), at: sample.location)
        case .ignored:
            return []
        }
    }

    /// Stops tracking the current drag (e.g. it carries no files) until the mouse is released.
    public mutating func ignoreCurrentDrag() {
        if case .dragging = state { state = .ignored }
    }

    private func wheelRequest(newlyPressed: Set<ModifierKey>, at point: WheelPoint) -> [DragTrackerOutput] {
        let kind = ModifierKey.allCases
            .filter(newlyPressed.contains)
            .lazy
            .compactMap(bindings.wheel(for:))
            .first
        return kind.map { [.wheelRequested($0, at: point)] } ?? []
    }
}
