@preconcurrency import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import TransfloDomain
import UniformTypeIdentifiers

/// Video → animated GIF with Apple's frameworks: frames sampled at `framesPerSecond`, fitted in a
/// `maximumWidth` square, looping forever. Long clips are sampled more sparsely to stay under `maximumFrames`.
enum VideoGIFWriter {
    static let framesPerSecond = 12.0
    static let maximumWidth = 480.0
    static let maximumFrames = 360

    /// Frames go straight to the encoder as they are read, so memory stays flat however long the clip is
    /// (the Share extension has little to spare). A frame that can't be read repeats the previous one.
    static func write(_ source: URL, to destination: URL, progress: @escaping @Sendable (Double) -> Void)
        async throws(JobError) {
        let duration = try await AVMediaComposer.duration(of: source)
        let times = frameTimes(duration: duration)
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: source))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maximumWidth, height: maximumWidth)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5 / framesPerSecond, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = generator.requestedTimeToleranceBefore
        let workspace = try TemporaryWorkspace(parent: destination.deletingLastPathComponent())
        defer { workspace.remove() }
        let staged = workspace.url.appendingPathComponent(destination.lastPathComponent)
        guard let output = CGImageDestinationCreateWithURL(staged as CFURL, UTType.gif.identifier as CFString,
                                                           times.count, nil) else { throw .destinationUnavailable }
        CGImageDestinationSetProperties(output, [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
        ] as CFDictionary)
        let frameProperties = [kCGImagePropertyGIFDictionary: [
            kCGImagePropertyGIFDelayTime: duration / Double(times.count)
        ]] as CFDictionary
        var previous: CGImage?
        for (index, time) in times.enumerated() {
            if Task.isCancelled { throw .cancelled }
            let read = try? await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image
            guard let frame = read ?? previous else { continue }
            CGImageDestinationAddImage(output, frame, frameProperties)
            previous = frame
            progress(Double(index + 1) / Double(times.count) * 0.9)
        }
        guard previous != nil, CGImageDestinationFinalize(output) else { throw .failed }
        try ToolOutputPublisher.publish(staged, to: destination, isCancelled: { Task.isCancelled })
        progress(1)
    }

    /// Evenly spaced sample times, at most `maximumFrames` of them.
    static func frameTimes(duration: Double) -> [Double] {
        let count = max(1, min(maximumFrames, Int((duration * framesPerSecond).rounded(.up))))
        return (0..<count).map { Double($0) * duration / Double(count) }
    }
}
