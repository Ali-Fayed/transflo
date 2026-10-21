#if os(macOS)
import Foundation
import TransfloDomain

/// Audio/video tools through the bundled ffmpeg: Compress, Rotate & flip, Mute, Normalize,
/// Mono, Merge, Remove metadata, and the editor tools Resize, Crop, Trim, Change speed,
/// Split and Snapshot.
public struct MediaToolEngine: ToolEngine {
    static let instantTools: Set<ToolKind> = [.compress, .rotate, .mute, .normalize, .channels, .removeMetadata]
    static let videoEditTools: Set<ToolKind> = [.resize, .crop, .snapshot]
    static let mediaEditTools: Set<ToolKind> = [.trim, .changeSpeed, .split, .bleep, .editMetadata]
    static var tools: Set<ToolKind> { instantTools.union(videoEditTools).union(mediaEditTools).union([.merge]) }

    private let ffmpeg: URL?
    private let ffprobe: URL?
    private let naming: ToolOutputNaming

    public init(ffmpeg: URL?, ffprobe: URL?, naming: ToolOutputNaming) {
        self.ffmpeg = ffmpeg
        self.ffprobe = ffprobe
        self.naming = naming
    }

    public func canRun(_ tool: ToolKind, on formats: [FormatDescriptor?]) -> Bool {
        guard ffmpeg != nil, Self.tools.contains(tool), !formats.isEmpty else { return false }
        if [.normalize, .channels].contains(tool), ffprobe == nil { return false }
        let ids = formats.map { $0?.id.rawValue ?? "" }
        if tool == .merge {
            let sameKind = ids.allSatisfy(FFmpegToolArguments.videoFormats.contains)
                || ids.allSatisfy(FFmpegToolArguments.audioFormats.contains)
            return ffprobe != nil && ids.count >= 2 && sameKind
        }
        if Self.videoEditTools.contains(tool) {
            return ffprobe != nil && ids.allSatisfy(FFmpegToolArguments.videoFormats.contains)
        }
        if Self.mediaEditTools.contains(tool) {
            let media = FFmpegToolArguments.videoFormats.union(FFmpegToolArguments.audioFormats)
            return ffprobe != nil && ids.allSatisfy(media.contains)
        }
        return ids.allSatisfy { arguments(for: tool, settings: .defaults(for: tool), format: $0) != nil }
    }

    public func run(
        _ request: ToolRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL] {
        guard let ffmpeg else { throw .unsupported }
        if case .compress(let goal) = request.settings {
            if case .level = goal {} else {
                return try await MediaTargetCompressor(ffmpeg: ffmpeg, ffprobe: ffprobe, naming: naming)
                    .run(request, goal: goal, progress: progress)
            }
        }
        if request.tool == .merge {
            let items: [ToolItem]
            if case .assemble(let assembly) = request.settings {
                guard let ordered = assembly.ordered(request.items) else { throw .unsupported }
                items = ordered
            } else { items = request.items }
            return [try await merge(items, ffmpeg: ffmpeg, progress: progress)]
        }
        let validatedSettings: ToolSettings = request.tool == .normalize && request.settings == .none
            ? .normalize(LoudnessSettings()) : request.settings
        try await ToolPreflight.media(request.items, settings: validatedSettings, ffprobe: ffprobe)
        var outputs: [URL] = []
        do throws(JobError) {
            for (index, item) in request.items.enumerated() {
                guard FileManager.default.fileExists(atPath: item.url.path) else { throw .sourceMissing }
                let steps = try await steps(for: request.tool, settings: request.settings, item: item)
                let share = 1 / Double(request.items.count * steps.count)
                for (stepIndex, step) in steps.enumerated() {
                    // Named just before writing, so each split part gets the next free number.
                    let destination = try naming.destination(
                        for: item.url, tool: request.tool, pathExtension: step.fileExtension
                    )
                    let done = Double(index * steps.count + stepIndex)
                    try await FFmpegRunner.run(binary: ffmpeg, arguments: step.arguments + [destination.path]) {
                        progress((done + $0) * share)
                    }
                    outputs.append(destination)
                }
            }
        } catch {
            throw outputs.isEmpty ? error : .partialFailure(completed: outputs, cause: error)
        }
        return outputs
    }

    private func steps(
        for tool: ToolKind, settings: ToolSettings, item: ToolItem
    ) async throws(JobError) -> [MediaToolStep] {
        let source = item.url.path
        let format = item.format?.id.rawValue ?? ""
        if tool == .normalize {
            let target: LoudnessSettings
            if case .normalize(let value) = settings { target = value } else { target = LoudnessSettings() }
            guard let ffmpeg else { throw .unsupported }
            let measured = try await LoudnessProcessor.measure(item.url, target: target, ffmpeg: ffmpeg)
            guard let arguments = LoudnessProcessor.arguments(target, measured: measured, format: format) else {
                throw .unsupported
            }
            return [MediaToolStep(arguments: ["-i", source] + arguments, fileExtension: nil)]
        }
        if tool == .removeMetadata, case .removeMetadata(let categories) = settings {
            return [MediaToolStep(arguments: ["-i", source]
                + (try await metadataArguments(item.url, categories: categories)), fileExtension: nil)]
        }
        if let instant = arguments(for: tool, settings: settings, format: format) {
            return [MediaToolStep(arguments: ["-i", source] + instant, fileExtension: nil)]
        }
        let info = Self.needsProbe(settings) ? try await probe(item.url) : nil
        guard let steps = MediaEditArguments.steps(for: settings, source: source, format: format, info: info) else {
            throw .unsupported
        }
        return steps
    }

    private static func needsProbe(_ settings: ToolSettings) -> Bool {
        switch settings {
        case .crop, .changeSpeed, .split, .bleep, .snapshot, .snapshotJPEG: true
        default: false
        }
    }

    private func probe(_ url: URL) async throws(JobError) -> MediaInfo {
        guard let ffprobe else { throw .unsupported }
        return try await FFprobe.info(binary: ffprobe, file: url)
    }

    private func arguments(for tool: ToolKind, settings: ToolSettings, format: String) -> [String]? {
        switch (tool, settings) {
        case let (.compress, .compress(.level(level))): FFmpegToolArguments.compress(format, level: level)
        case let (.rotate, .rotate(turns, flipH, flipV)):
            FFmpegToolArguments.rotate(format, quarterTurns: turns, flipHorizontal: flipH, flipVertical: flipV)
        case (.mute, _): FFmpegToolArguments.mute(format)
        case (.normalize, _): FFmpegToolArguments.normalize(format)
        case (.channels, .channels(let mix)): FFmpegToolArguments.mono(format, mix: mix)
        case (.channels, _): FFmpegToolArguments.mono(format)
        case (.removeMetadata, _):
            FFmpegToolArguments.videoFormats.union(FFmpegToolArguments.audioFormats).contains(format)
                ? FFmpegToolArguments.stripMetadata : nil
        default: nil
        }
    }

    private func metadataArguments(_ url: URL, categories: Set<MetadataCategory>) async throws(JobError) -> [String] {
        if categories == Set(MetadataCategory.allCases) { return FFmpegToolArguments.stripMetadata }
        let info = try await probe(url)
        let removed = info.tags.keys.filter { categories.contains(MetadataFiltering.category($0)) }.sorted()
        return ["-map", "0", "-c", "copy"] + removed.flatMap { ["-metadata", "\($0)=", "-metadata:s", "\($0)="] }
    }

    private func merge(
        _ items: [ToolItem], ffmpeg: URL, progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> URL {
        guard let ffprobe, let first = items.first else { throw .unsupported }
        var inputs: [(path: String, info: MediaInfo)] = []
        for item in items {
            guard FileManager.default.fileExists(atPath: item.url.path) else { throw .sourceMissing }
            inputs.append((item.url.path, try await FFprobe.info(binary: ffprobe, file: item.url)))
        }
        let format = first.format?.id.rawValue ?? ""
        guard let arguments = MergePlan.arguments(inputs: inputs, format: format) else { throw .unsupported }
        let destination = try naming.destination(for: first.url, tool: .merge)
        let total = inputs.compactMap(\.info.duration).reduce(0, +)
        try await FFmpegRunner.run(
            binary: ffmpeg, arguments: arguments + [destination.path], totalDuration: total, progress: progress
        )
        return destination
    }
}
#endif
