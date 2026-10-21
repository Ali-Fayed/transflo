import Foundation
import TransfloDomain

/// Watches system-wide file drags and publishes `DragEvent`s.
///
/// Polling runs only between a mouse-down and the matching mouse-up, so the idle cost is zero.
/// No Accessibility or Input Monitoring permission is needed: it reads public state
/// (`NSEvent.modifierFlags`, the drag pasteboard) rather than tapping key events.
@MainActor
public final class DragMonitor {
    /// Drag lifecycle events, newest kept if the consumer falls behind.
    public let events: AsyncStream<DragEvent>

    private let continuation: AsyncStream<DragEvent>.Continuation
    private let sampler: any DragSampling
    private let ticker: any Ticking
    private let mouseDown: any MouseDownObserving
    private var tracker: DragTracker
    private var isPolling = false
    /// New bindings wait for the current drag to end.
    private var pendingBindings: WheelKeyBindings?

    public init(
        bindings: WheelKeyBindings,
        sampler: any DragSampling,
        ticker: any Ticking,
        mouseDown: any MouseDownObserving
    ) {
        (events, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(32))
        self.tracker = DragTracker(bindings: bindings)
        self.sampler = sampler
        self.ticker = ticker
        self.mouseDown = mouseDown
    }

    /// Starts listening for mouse-downs.
    public func start() {
        mouseDown.start { [weak self] in self?.beginPolling() }
    }

    /// Switches to `bindings`; a drag in progress keeps the old ones until it ends.
    public func update(bindings: WheelKeyBindings) {
        if isPolling {
            pendingBindings = bindings
        } else {
            tracker = DragTracker(bindings: bindings)
        }
    }

    /// Stops listening and finishes the event stream.
    public func stop() {
        mouseDown.stop()
        stopPolling()
        continuation.finish()
    }

    private func beginPolling() {
        guard !isPolling else { return }
        isPolling = true
        ticker.start { [weak self] in self?.tick() }
        tick()
    }

    private func stopPolling() {
        ticker.stop()
        isPolling = false
        if let pendingBindings {
            tracker = DragTracker(bindings: pendingBindings)
            self.pendingBindings = nil
        }
    }

    private func tick() {
        let sample = sampler.sample()
        for output in tracker.process(sample) {
            handle(output)
        }
        if !sample.isMouseDown {
            stopPolling()
        }
    }

    private func handle(_ output: DragTrackerOutput) {
        switch output {
        case .began:
            let items = sampler.draggedFileURLs()
            if items.isEmpty {
                tracker.ignoreCurrentDrag()
            } else {
                continuation.yield(.began(items: items))
            }
        case let .wheelRequested(kind, point):
            continuation.yield(.wheelRequested(kind, at: point))
        case .ended:
            continuation.yield(.ended)
        }
    }
}
