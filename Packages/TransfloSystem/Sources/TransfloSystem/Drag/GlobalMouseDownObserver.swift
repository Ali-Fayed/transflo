import AppKit

/// Observes left mouse-downs in other apps through a global event monitor (no permission required).
@MainActor
public final class GlobalMouseDownObserver: MouseDownObserving {
    private var monitor: Any?

    public init() {}

    public func start(_ handler: @escaping @MainActor () -> Void) {
        stop()
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { _ in
            MainActor.assumeIsolated { handler() }
        }
    }

    public func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}
