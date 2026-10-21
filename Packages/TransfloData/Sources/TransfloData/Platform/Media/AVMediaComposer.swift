@preconcurrency import AVFoundation
import Foundation
import TransfloDomain

/// Builds the compositions behind Trim, Mute, Change Speed, Split and Merge from source files'
/// tracks, without re-encoding anything until export.
enum AVMediaComposer {
    /// The longest a source may be: anything longer than a day is almost certainly a broken file.
    static let maximumDuration: Double = 86_400

    static func duration(of url: URL) async throws(JobError) -> Double {
        guard FileManager.default.fileExists(atPath: url.path) else { throw .sourceMissing }
        let seconds = (try? await AVURLAsset(url: url).load(.duration).seconds) ?? 0
        guard seconds.isFinite, seconds > 0, seconds <= maximumDuration else { throw .failed }
        return seconds
    }

    /// `sources` back to back, each limited to `range` (whole file when `nil`), keeping audio unless
    /// `includesAudio` is false, then stretched by `speed` (2 = twice as fast).
    static func compose(
        _ sources: [URL],
        range: ClosedRange<Double>? = nil,
        includesAudio: Bool = true,
        speed: Double = 1
    ) async throws(JobError) -> AVMutableComposition {
        guard !sources.isEmpty, speed.isFinite, (0.25...4).contains(speed) else { throw .unsupported }
        let composition = AVMutableComposition()
        let video = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let audio = includesAudio
            ? composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            : nil
        var cursor = CMTime.zero
        for source in sources {
            let added = try await append(source, range: range, video: video, audio: audio, at: cursor)
            cursor = CMTimeAdd(cursor, added)
        }
        for track in composition.tracks where track.segments.isEmpty { composition.removeTrack(track) }
        guard !composition.tracks.isEmpty, cursor > .zero else { throw .failed }
        if speed != 1 {
            let whole = CMTimeRange(start: .zero, duration: cursor)
            composition.scaleTimeRange(whole, toDuration: CMTimeMultiplyByFloat64(cursor, multiplier: 1 / speed))
        }
        return composition
    }

    /// Inserts `source`'s first video and audio tracks at `cursor`; returns the length it added.
    private static func append(
        _ source: URL,
        range: ClosedRange<Double>?,
        video: AVMutableCompositionTrack?,
        audio: AVMutableCompositionTrack?,
        at cursor: CMTime
    ) async throws(JobError) -> CMTime {
        guard FileManager.default.fileExists(atPath: source.path) else { throw .sourceMissing }
        let asset = AVURLAsset(url: source)
        do {
            let timeRange = try Self.timeRange(range, within: try await asset.load(.duration))
            if let track = try await asset.loadTracks(withMediaType: .video).first, let video {
                try video.insertTimeRange(timeRange, of: track, at: cursor)
                if cursor == .zero { video.preferredTransform = try await track.load(.preferredTransform) }
            }
            if let track = try await asset.loadTracks(withMediaType: .audio).first, let audio {
                try audio.insertTimeRange(timeRange, of: track, at: cursor)
            }
            return timeRange.duration
        } catch let error as JobError {
            throw error
        } catch {
            throw .failed
        }
    }

    /// `range` in seconds clamped to the source, or the whole source.
    static func timeRange(_ range: ClosedRange<Double>?, within length: CMTime) throws(JobError) -> CMTimeRange {
        guard let range else { return CMTimeRange(start: .zero, duration: length) }
        let total = length.seconds
        let start = max(0, range.lowerBound), end = min(total, range.upperBound)
        guard start.isFinite, end.isFinite, end - start >= 0.1 else { throw .incompatibleSelection }
        let timescale: CMTimeScale = 600
        return CMTimeRange(start: CMTime(seconds: start, preferredTimescale: timescale),
                           end: CMTime(seconds: end, preferredTimescale: timescale))
    }

    /// Consecutive `[start, end]` parts between `points` (seconds), dropping slivers under 0.1 s.
    static func parts(splitting duration: Double, at points: [Double]) -> [ClosedRange<Double>] {
        let cuts = ([0] + points.filter { $0 > 0 && $0 < duration }.sorted() + [duration])
        return zip(cuts, cuts.dropFirst()).compactMap { $1 - $0 >= 0.1 ? $0...$1 : nil }
    }
}
