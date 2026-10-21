@preconcurrency import AVFoundation
import Foundation
import os
import TransfloDomain

/// Apple-native media conversions: MP4 ↔ MOV through export sessions (passthrough when the
/// codecs allow), video → M4A (the soundtrack) and animated GIF, and audio → M4A/WAV/AIFF through
/// `AVAudioFile`.
public struct AVFoundationEngine: ConversionEngine {
    public let id = EngineIDs.avFoundation
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.transflo.app",
        category: "AVFoundation"
    )

    static let videoFormats: Set<String> = ["mp4", "mov"]
    static let audioSources: Set<String> = ["mp3", "m4a", "wav", "flac", "aiff"]
    static let audioTargets: Set<String> = ["m4a", "wav", "aiff"]

    public init() {}

    public func canConvert(from source: FormatDescriptor, to target: FormatDescriptor) -> Bool {
        let (from, to) = (source.id.rawValue, target.id.rawValue)
        return (Self.videoFormats.contains(from) && (Self.videoFormats.contains(to) || ["m4a", "gif"].contains(to)))
            || (Self.audioSources.contains(from) && Self.audioTargets.contains(to))
    }

    public func convert(
        _ request: ConversionRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL] {
        guard FileManager.default.fileExists(atPath: request.source.path) else { throw .sourceMissing }
        let source = request.sourceFormat.id.rawValue, target = request.targetFormat.id.rawValue
        if Self.videoFormats.contains(target) {
            try await exportVideo(request, progress: progress)
        } else if Self.videoFormats.contains(source), target == "gif" {
            try await VideoGIFWriter.write(request.source, to: request.destination, progress: progress)
        } else if Self.videoFormats.contains(source) {
            try await extractAudio(request, progress: progress)
        } else {
            try await BlockingWork.runCancellable { isCancelled throws(JobError) in
                try AudioFileTranscoder.transcode(request, isCancelled: isCancelled, progress: progress)
            }
        }
        progress(1)
        return [request.destination]
    }

    private func exportVideo(
        _ request: ConversionRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) {
        let workspace = try TemporaryWorkspace(parent: request.destination.deletingLastPathComponent())
        defer { workspace.remove() }
        let staged = workspace.url.appendingPathComponent(request.destination.lastPathComponent)
        let asset = AVURLAsset(url: request.source)
        let fileType: AVFileType = request.targetFormat.id.rawValue == "mov" ? .mov : .mp4
        let preset = await Self.preset(for: asset, fileType: fileType)
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else { throw .failed }
        let export = ExportHandle(session)
        progress(0.1)
        do {
            try await withTaskCancellationHandler {
                guard !Task.isCancelled else { throw CancellationError() }
                if #available(iOS 18, macOS 15, *) {
                    try await export.session.export(to: staged, as: fileType)
                } else {
                    export.session.outputURL = staged
                    export.session.outputFileType = fileType
                    await export.session.export()
                    if let error = export.session.error { throw error }
                    guard export.session.status == .completed else { throw JobError.failed }
                }
            } onCancel: {
                export.session.cancelExport()
            }
        } catch {
            Self.logger.error("Export failed: \(String(describing: error), privacy: .private)")
            throw Task.isCancelled ? .cancelled : .failed
        }
        try ToolOutputPublisher.publish(staged, to: request.destination, isCancelled: { Task.isCancelled })
    }

    /// The soundtrack alone, as AAC in M4A.
    private func extractAudio(_ request: ConversionRequest, progress: @escaping @Sendable (Double) -> Void)
        async throws(JobError) {
        let asset = AVURLAsset(url: request.source)
        let tracks = (try? await asset.loadTracks(withMediaType: .audio)) ?? []
        guard !tracks.isEmpty else { throw .nothingFound }
        try await AVMediaExport.export(asset, preset: AVAssetExportPresetAppleM4A, fileType: .m4a,
                                       to: request.destination, progress: progress)
    }

    /// Passthrough keeps quality and is near-instant when the container accepts the streams.
    private static func preset(for asset: AVURLAsset, fileType: AVFileType) async -> String {
        let passthrough = AVAssetExportPresetPassthrough
        let types = await AVAssetExportSession.compatibleFileTypes(for: asset, presetName: passthrough)
        return types.contains(fileType) ? passthrough : AVAssetExportPresetHighestQuality
    }
}

private extension AVAssetExportSession {
    /// macOS 14 bridge for the completion-handler API.
    static func compatibleFileTypes(for asset: AVAsset, presetName: String) async -> [AVFileType] {
        guard let session = AVAssetExportSession(asset: asset, presetName: presetName) else { return [] }
        return await withCheckedContinuation { continuation in
            session.determineCompatibleFileTypes { continuation.resume(returning: $0) }
        }
    }
}

// @unchecked: the session is configured on one task; cancelExport is the only concurrent operation.
private final class ExportHandle: @unchecked Sendable {
    let session: AVAssetExportSession

    init(_ session: AVAssetExportSession) { self.session = session }
}
