import Foundation

/// Playback labels and the scrubber describe the selected output interval, rather than the source.
struct MobileMediaTimeline {
    let start: Double
    let end: Double
    let rate: Double

    init(duration: Double, start: Double, end: Double, rate: Double = 1) {
        let duration = duration.isFinite ? max(0, duration) : 0
        self.start = min(duration, max(0, start))
        self.end = min(duration, max(self.start, end))
        self.rate = rate.isFinite && rate > 0 ? rate : 1
    }

    var duration: Double { (end - start) / rate }

    func elapsed(at sourceTime: Double) -> Double {
        min(duration, max(0, sourceTime - start) / rate)
    }

    func sourceTime(at elapsed: Double) -> Double {
        min(end, max(start, start + elapsed * rate))
    }
}
