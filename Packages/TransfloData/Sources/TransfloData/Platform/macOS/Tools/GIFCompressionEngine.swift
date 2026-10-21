#if os(macOS)
import Foundation
import TransfloDomain

/// Compress for animated GIFs: re-encodes every frame with ffmpeg using a palette built from what
/// changes between frames, fewer colors and, at stronger levels, smaller frames. Size targets try
/// each step in turn until one fits.
public struct GIFCompressionEngine: ToolEngine {
    struct Step: Equatable {
        let colors: Int
        let scale: Double
    }

    /// Light, medium and strong start at the first three steps; any goal may go further down.
    static let ladder = [
        Step(colors: 256, scale: 1), Step(colors: 128, scale: 1),
        Step(colors: 64, scale: 0.75), Step(colors: 32, scale: 0.5)
    ]

    private let ffmpeg: URL?
    private let naming: ToolOutputNaming

    public init(ffmpeg: URL?, naming: ToolOutputNaming) {
        self.ffmpeg = ffmpeg
        self.naming = naming
    }

    public func canRun(_ tool: ToolKind, on formats: [FormatDescriptor?]) -> Bool {
        tool == .compress && ffmpeg != nil && !formats.isEmpty && formats.allSatisfy { $0?.id.rawValue == "gif" }
    }

    public func run(
        _ request: ToolRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL] {
        guard let ffmpeg else { throw .unsupported }
        let (goal, edge) = try Self.goal(request.settings)
        var outputs: [URL] = []
        do throws(JobError) {
            for (index, item) in request.items.enumerated() {
                if Task.isCancelled { throw .cancelled }
                guard FileManager.default.fileExists(atPath: item.url.path) else { throw .sourceMissing }
                let output = try naming.destination(for: item.url, tool: .compress)
                let share = 1 / Double(request.items.count)
                let report: @Sendable (Double) -> Void = { progress((Double(index) + $0) * share) }
                try await compress(item.url, plan: (goal, edge), ffmpeg: ffmpeg, to: output, progress: report)
                outputs.append(output)
            }
        } catch {
            throw outputs.isEmpty ? error : .partialFailure(completed: outputs, cause: error)
        }
        return outputs
    }

    static func goal(_ settings: ToolSettings) throws(JobError) -> (CompressionGoal, Int?) {
        switch settings {
        case .compress(let goal): return (goal, nil)
        case let .compressImage(goal, edge):
            if let edge, !(1...16_384).contains(edge) { throw .unsupported }
            return (goal, edge)
        default: throw .unsupported
        }
    }

    static func index(for level: CompressionLevel) -> Int {
        switch level {
        case .light: 0
        case .medium: 1
        case .strong: 2
        }
    }

    /// Encodes from the goal's step down the ladder and keeps the first result that is smaller than
    /// the original (for a level) or fits the budget (for a size target).
    private func compress(
        _ source: URL,
        plan: (goal: CompressionGoal, edge: Int?),
        ffmpeg: URL,
        to output: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) {
        let (goal, edge) = plan
        guard let size = try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize else { throw .sourceMissing }
        let steps: ArraySlice<Step>
        let budget: Int64
        if case .level(let level) = goal {
            steps = Self.ladder[Self.index(for: level)...]
            budget = Int64(size) - 1
        } else {
            guard let bytes = goal.byteBudget(originalBytes: Int64(size)) else { throw .targetUnreachable }
            steps = Self.ladder[...]
            budget = bytes
        }
        let workspace = try TemporaryWorkspace(parent: output.deletingLastPathComponent())
        defer { workspace.remove() }
        for (attempt, step) in steps.enumerated() {
            let candidate = workspace.url.appendingPathComponent("candidate-\(attempt).gif")
            let arguments = Self.arguments(input: source, step: step, maximumLongEdge: edge)
            try await FFmpegRunner.run(binary: ffmpeg, arguments: arguments + [candidate.path]) {
                progress((Double(attempt) + $0) / Double(steps.count))
            }
            guard let bytes = try? candidate.resourceValues(forKeys: [.fileSizeKey]).fileSize else { throw .failed }
            if Int64(bytes) <= budget {
                try ToolOutputPublisher.publish(candidate, to: output, isCancelled: { Task.isCancelled })
                return
            }
        }
        // Already as small as these settings make it.
        if case .level = goal { throw .nothingFound }
        throw .targetUnreachable
    }

    /// One palette per animation, weighted toward the pixels that change, so static areas don't
    /// shimmer; only the changed rectangle of each frame is redrawn.
    static func arguments(input: URL, step: Step, maximumLongEdge: Int?) -> [String] {
        var filters: [String] = []
        if step.scale < 1 {
            filters.append("scale=trunc(iw*\(step.scale)):-1:flags=lanczos")
        }
        if let edge = maximumLongEdge {
            filters.append("scale='min(iw,\(edge))':'min(ih,\(edge))'"
                + ":force_original_aspect_ratio=decrease:flags=lanczos")
        }
        let prefix = filters.isEmpty ? "" : filters.joined(separator: ",") + ","
        let graph = prefix + "split[a][b];[a]palettegen=max_colors=\(step.colors):stats_mode=diff[p];"
            + "[b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle"
        return ["-i", input.path, "-filter_complex", graph, "-loop", "0", "-f", "gif"]
    }
}
#endif
