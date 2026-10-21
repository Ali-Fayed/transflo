#if os(macOS)
import Foundation
import os
import TransfloDomain

/// Runs the bundled ffmpeg with Transflo's safety flags (`-n` never overwrites, stdin closed) and
/// turns its `-progress` output into a 0...1 fraction.
enum FFmpegRunner {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.transflo.app",
        category: "FFmpeg"
    )
    static let safetyFlags = ["-hide_banner", "-nostdin", "-n", "-progress", "pipe:1", "-nostats"]
    /// Apple's hardware encoders fail intermittently when too many sessions open at once, so those
    /// encodes share a small pool. They also decode in hardware; the one retry decodes in software.
    static let hardwareEncoder = "h264_videotoolbox"
    static let hardwareEncoders: Set<String> = [hardwareEncoder, "hevc_videotoolbox"]
    static let hardwareGate = ConcurrencyGate(limit: 4)

    /// `arguments` with hardware decoding requested for every input.
    static func hardwareDecoding(_ arguments: [String]) -> [String] {
        arguments.enumerated().flatMap { index, argument in
            let requested = index >= 2 && arguments[index - 2] == "-hwaccel"
            return argument == "-i" && !requested ? ["-hwaccel", "videotoolbox", argument] : [argument]
        }
    }

    /// - Parameter totalDuration: Seconds of output expected, when the first input's banner
    ///   duration is not the whole (e.g. merges).
    static func run(
        binary: URL,
        arguments: [String],
        totalDuration: Double? = nil,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) {
        guard let path = arguments.last else { throw .unsupported }
        let output = URL(fileURLWithPath: path)
        guard !FileManager.default.fileExists(atPath: output.path) else { throw .destinationOccupied }
        let workspace = try TemporaryWorkspace(parent: output.deletingLastPathComponent())
        defer { workspace.remove() }
        let staged = workspace.url.appendingPathComponent(output.lastPathComponent)
        let stagedArguments = Array(arguments.dropLast()) + [staged.path]
        do throws(JobError) {
            try await encode(
                binary: binary, arguments: stagedArguments, totalDuration: totalDuration, progress: progress
            )
        } catch {
            // A concurrent writer may have published while we were encoding. Signal ownership
            // explicitly so callers do not mistake that file for our partial output.
            if FileManager.default.fileExists(atPath: output.path) { throw .destinationOccupied }
            throw error
        }
        if Task.isCancelled { throw .cancelled }
        guard let size = try? staged.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 0 else {
            throw .failed
        }
        try ToolOutputPublisher.publish(staged, to: output, isCancelled: { Task.isCancelled })
    }

    private static func encode(
        binary: URL,
        arguments: [String],
        totalDuration: Double?,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) {
        guard !hardwareEncoders.isDisjoint(with: arguments) else {
            try await runOnce(binary: binary, arguments: arguments, totalDuration: totalDuration, progress: progress)
            return
        }
        try await hardwareGate.run { () async throws(JobError) in
            do throws(JobError) {
                try await runOnce(binary: binary, arguments: hardwareDecoding(arguments),
                                  totalDuration: totalDuration, progress: progress)
            } catch JobError.failed {
                // Only the private staged file belongs to this attempt. Retry with software decoding.
                if let output = arguments.last { try? FileManager.default.removeItem(atPath: output) }
                try await runOnce(binary: binary, arguments: arguments,
                                  totalDuration: totalDuration, progress: progress)
            }
        }
    }

    private static func runOnce(
        binary: URL,
        arguments: [String],
        totalDuration: Double?,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) {
        let state = FFmpegRunState(progress: progress, duration: totalDuration)
        let status = await ProcessRunner.run(
            executable: binary,
            arguments: safetyFlags + arguments,
            onStdoutLine: state.handleProgressLine,
            onStderrLine: state.handleStderrLine
        )
        if Task.isCancelled { throw .cancelled }
        guard let status else { throw .unsupported }
        guard status == 0 else {
            logger.error("ffmpeg exited \(status, privacy: .public): \(state.lastErrors, privacy: .private)")
            throw .failed
        }
    }
}

// @unchecked: all mutable state is guarded by `lock`.
/// Tracks duration and reports progress for one ffmpeg run.
final class FFmpegRunState: @unchecked Sendable {
    private let lock = NSLock()
    private let progress: @Sendable (Double) -> Void
    private var duration: Double?
    private var errors: [String] = []

    init(progress: @escaping @Sendable (Double) -> Void, duration: Double? = nil) {
        self.progress = progress
        self.duration = duration
    }

    var lastErrors: String { lock.withLock { errors.suffix(5).joined(separator: " | ") } }

    func handleStderrLine(_ line: String) {
        lock.withLock {
            if duration == nil { duration = FFmpegProgressParser.duration(fromStderrLine: line) }
            errors.append(line)
            if errors.count > 20 { errors.removeFirst() }
        }
    }

    func handleProgressLine(_ line: String) {
        guard let encoded = FFmpegProgressParser.encodedSeconds(fromProgressLine: line),
              let duration = lock.withLock({ duration }), duration > 0 else { return }
        progress(min(encoded / duration, 0.99))
    }
}
#endif
