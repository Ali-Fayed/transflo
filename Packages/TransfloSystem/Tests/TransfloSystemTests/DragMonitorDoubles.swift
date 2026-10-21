import Foundation
import TransfloDomain
@testable import TransfloSystem

/// Returns scripted samples in order, repeating the last one.
@MainActor
final class ScriptedDragSampler: DragSampling {
    var samples: [DragSample]
    var fileURLs: [URL]
    private(set) var sampleCount = 0

    init(samples: [DragSample] = [], fileURLs: [URL] = []) {
        self.samples = samples
        self.fileURLs = fileURLs
    }

    func sample() -> DragSample {
        sampleCount += 1
        return samples.count > 1 ? samples.removeFirst() : samples[0]
    }

    func draggedFileURLs() -> [URL] {
        fileURLs
    }
}

/// A ticker fired by the test.
@MainActor
final class ManualTicker: Ticking {
    private var tick: (@MainActor () -> Void)?
    private(set) var startCount = 0
    var isRunning: Bool { tick != nil }

    func start(_ tick: @escaping @MainActor () -> Void) {
        startCount += 1
        self.tick = tick
    }

    func stop() {
        tick = nil
    }

    func fire(times: Int = 1) {
        for _ in 0..<times {
            tick?()
        }
    }
}

/// A mouse-down source triggered by the test.
@MainActor
final class ManualMouseDown: MouseDownObserving {
    private var handler: (@MainActor () -> Void)?
    private(set) var isStopped = false

    func start(_ handler: @escaping @MainActor () -> Void) {
        self.handler = handler
    }

    func stop() {
        isStopped = true
        handler = nil
    }

    func press() {
        handler?()
    }
}
