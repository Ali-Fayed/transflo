import Foundation

/// A main-run-loop timer in common modes, so it keeps firing while menus or drags track events.
@MainActor
public final class MainRunLoopTicker: Ticking {
    private let interval: TimeInterval
    private var timer: Timer?

    /// - Parameter interval: Seconds between ticks; 60 Hz by default.
    public init(interval: TimeInterval = 1.0 / 60) {
        self.interval = interval
    }

    public func start(_ tick: @escaping @MainActor () -> Void) {
        stop()
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            MainActor.assumeIsolated { tick() }
        }
        // A little slack lets macOS coalesce these wakeups with others, which saves energy while dragging.
        timer.tolerance = interval * 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }
}
