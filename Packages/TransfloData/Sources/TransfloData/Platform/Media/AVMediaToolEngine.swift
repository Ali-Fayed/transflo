@preconcurrency import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import TransfloDomain
import UniformTypeIdentifiers

/// Media tools on Apple's frameworks (iPhone and iPad, where ffmpeg can't run): Trim, Mute, Change
/// Speed, Snapshot, Split and Merge for MP4/MOV video and M4A/MP3/WAV/AIFF/CAF audio.
///
/// Video keeps its container; audio is written as M4A (AAC), the format Apple's export supports.
public struct AVMediaToolEngine: ToolEngine {
    static let tools: Set<ToolKind> = [.trim, .mute, .changeSpeed, .snapshot, .split, .merge]
    static let videoFormats: Set<String> = ["mp4", "mov", "m4v"]
    static let audioFormats: Set<String> = ["m4a", "mp3", "wav", "aiff", "caf"]

    private let naming: ToolOutputNaming

    public init(naming: ToolOutputNaming) {
        self.naming = naming
    }

    public func canRun(_ tool: ToolKind, on formats: [FormatDescriptor?]) -> Bool {
        guard Self.tools.contains(tool), !formats.isEmpty else { return false }
        let ids = formats.map { $0?.id.rawValue ?? "" }
        let video = ids.allSatisfy(Self.videoFormats.contains), audio = ids.allSatisfy(Self.audioFormats.contains)
        switch tool {
        case .mute, .snapshot: return video
        case .merge: return ids.count >= 2 && (video || audio)
        default: return video || audio
        }
    }

    public func run(
        _ request: ToolRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL] {
        guard canRun(request.tool, on: request.items.map(\.format)) else { throw .unsupported }
        let urls = request.items.map(\.url)
        switch (request.tool, request.settings) {
        case (.merge, _):
            return [try await export(urls, tool: .merge, progress: progress)]
        case (.split, .split(let points)):
            return try await split(urls, at: points, progress: progress)
        default:
            return try await perFile(request, progress: progress)
        }
    }

    private func perFile(_ request: ToolRequest, progress: @escaping @Sendable (Double) -> Void)
        async throws(JobError) -> [URL] {
        var outputs: [URL] = []
        let count = Double(request.items.count)
        do throws(JobError) {
            for (index, item) in request.items.enumerated() {
                if Task.isCancelled { throw .cancelled }
                let report: @Sendable (Double) -> Void = { progress((Double(index) + $0) / count) }
                switch (request.tool, request.settings) {
                case let (.trim, .trim(start, end)):
                    outputs.append(try await export([item.url], tool: .trim, range: start...end, progress: report))
                case (.mute, _):
                    outputs.append(try await export([item.url], tool: .mute, includesAudio: false, progress: report))
                case (.changeSpeed, .changeSpeed(let factor)):
                    outputs.append(try await export([item.url], tool: .changeSpeed, speed: factor, progress: report))
                case (.snapshot, .snapshot(let time)):
                    outputs.append(try await snapshot(item.url, at: time, jpegQuality: nil))
                case let (.snapshot, .snapshotJPEG(time, quality)):
                    outputs.append(try await snapshot(item.url, at: time, jpegQuality: quality))
                default:
                    throw .unsupported
                }
            }
        } catch {
            throw outputs.isEmpty ? error : .partialFailure(completed: outputs, cause: error)
        }
        return outputs
    }

    private func split(_ urls: [URL], at points: [Double], progress: @escaping @Sendable (Double) -> Void)
        async throws(JobError) -> [URL] {
        guard urls.count == 1, let source = urls.first, !points.isEmpty else { throw .unsupported }
        let parts = AVMediaComposer.parts(splitting: try await AVMediaComposer.duration(of: source), at: points)
        guard parts.count >= 2 else { throw .incompatibleSelection }
        var outputs: [URL] = []
        do throws(JobError) {
            for (index, part) in parts.enumerated() {
                if Task.isCancelled { throw .cancelled }
                let report: @Sendable (Double) -> Void = { progress((Double(index) + $0) / Double(parts.count)) }
                outputs.append(try await export([source], tool: .split, range: part, progress: report))
            }
        } catch {
            throw outputs.isEmpty ? error : .partialFailure(completed: outputs, cause: error)
        }
        return outputs
    }

    private func export(
        _ sources: [URL],
        tool: ToolKind,
        range: ClosedRange<Double>? = nil,
        includesAudio: Bool = true,
        speed: Double = 1,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> URL {
        guard let first = sources.first else { throw .unsupported }
        let composition = try await AVMediaComposer.compose(sources, range: range, includesAudio: includesAudio,
                                                            speed: speed)
        let isVideo = Self.videoFormats.contains(first.pathExtension.lowercased())
        let fileExtension = isVideo ? (first.pathExtension.lowercased() == "mov" ? "mov" : "mp4") : "m4a"
        let fileType: AVFileType = isVideo ? (fileExtension == "mov" ? .mov : .mp4) : .m4a
        let reencode = isVideo ? AVAssetExportPresetHighestQuality : AVAssetExportPresetAppleM4A
        // Speed changes and merged sources need new timing, so they always re-encode.
        let preset = speed == 1 && sources.count == 1 && isVideo
            ? await AVMediaExport.preset(for: composition, fileType: fileType, reencode: reencode) : reencode
        let destination = try naming.destination(for: first, tool: tool, pathExtension: fileExtension)
        try await AVMediaExport.export(composition, preset: preset, fileType: fileType, to: destination,
                                       configure: { $0.audioTimePitchAlgorithm = .spectral }, progress: progress)
        return destination
    }

    /// One frame at `time` (seconds, clamped to the video) as PNG, or JPEG at `jpegQuality` percent.
    private func snapshot(_ source: URL, at time: Double, jpegQuality: Int?) async throws(JobError) -> URL {
        let duration = try await AVMediaComposer.duration(of: source)
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: source))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let seconds = min(max(0, time.isFinite ? time : 0), max(0, duration - 0.05))
        let image: CGImage
        do {
            image = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600)).image
        } catch {
            throw .failed
        }
        let jpeg = jpegQuality != nil
        let destination = try naming.destination(for: source, tool: .snapshot, pathExtension: jpeg ? "jpg" : "png")
        try OutputFile.write(to: destination) { staged throws(JobError) in
            let type = (jpeg ? UTType.jpeg : UTType.png).identifier as CFString
            guard let output = CGImageDestinationCreateWithURL(staged as CFURL, type, 1, nil) else {
                throw .destinationUnavailable
            }
            let quality = Double(min(max(jpegQuality ?? 90, 1), 100)) / 100
            CGImageDestinationAddImage(output, image, [kCGImageDestinationLossyCompressionQuality: quality]
                as CFDictionary)
            guard CGImageDestinationFinalize(output) else { throw .failed }
        }
        return destination
    }
}
