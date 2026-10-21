#if os(iOS)
@preconcurrency import AVFoundation
import Foundation
import TransfloDomain

/// Native mobile compression preserves the source and exports a separate, shareable MP4.
public struct NativeVideoToolEngine: ToolEngine {
    private let naming: ToolOutputNaming

    public init(naming: ToolOutputNaming) { self.naming = naming }

    public func canRun(_ tool: ToolKind, on formats: [FormatDescriptor?]) -> Bool {
        tool == .compress && !formats.isEmpty
            && formats.allSatisfy { ["mp4", "mov"].contains($0?.id.rawValue ?? "") }
    }

    public func run(
        _ request: ToolRequest, progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL] {
        guard canRun(request.tool, on: request.items.map(\.format)),
              case .compress(.level(let level)) = request.settings else { throw .unsupported }
        var outputs: [URL] = []
        do throws(JobError) {
            for (index, item) in request.items.enumerated() {
                if Task.isCancelled { throw .cancelled }
                guard FileManager.default.fileExists(atPath: item.url.path) else { throw .sourceMissing }
                let destination = try naming.destination(for: item.url, tool: .compress, pathExtension: "mp4")
                try await compress(item.url, to: destination, level: level) {
                    progress((Double(index) + $0) / Double(request.items.count))
                }
                outputs.append(destination)
            }
        } catch {
            throw outputs.isEmpty ? error : .partialFailure(completed: outputs, cause: error)
        }
        return outputs
    }

    /// Best is HEVC up to 1080p, Balanced H.264 720p, Smaller H.264 480p, as on the Mac, where Smaller
    /// also switches codec. A level that doesn't make the file smaller falls through to the next.
    static func presets(from level: CompressionLevel) -> [String] {
        let ladder = [AVAssetExportPresetHEVC1920x1080, AVAssetExportPreset1280x720, AVAssetExportPreset640x480]
        return Array(ladder.dropFirst(CompressionLevel.allCases.firstIndex(of: level) ?? 1))
    }

    private func compress(
        _ source: URL,
        to destination: URL,
        level: CompressionLevel,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) {
        guard let original = try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            throw .sourceMissing
        }
        let workspace = try TemporaryWorkspace(parent: destination.deletingLastPathComponent())
        defer { workspace.remove() }
        let presets = Self.presets(from: level)
        for (attempt, preset) in presets.enumerated() {
            let candidate = workspace.url.appendingPathComponent("compressed-\(attempt).mp4")
            do {
                try await AVMediaExport.export(AVURLAsset(url: source), preset: preset, fileType: .mp4,
                                               to: candidate) {
                    progress(min(0.95, (Double(attempt) + $0) / Double(presets.count)))
                }
            } catch .unsupported {
                continue
            }
            guard let size = try? candidate.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                  size < original else { continue }
            try ToolOutputPublisher.publish(candidate, to: destination, isCancelled: { Task.isCancelled })
            progress(1)
            return
        }
        throw .nothingFound
    }
}
#endif
