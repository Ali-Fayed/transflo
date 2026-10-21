#if os(macOS)
import Foundation
import TransfloDomain

/// Conversions through the bundled LGPL ffmpeg helper (Adapter over `Process`).
///
/// Arguments are always an array, `-n` refuses to overwrite, stdin is closed, and progress
/// comes from `-progress pipe:1` measured against the input duration.
public struct FFmpegEngine: ConversionEngine {
    public let id = EngineIDs.ffmpeg
    private let binary: URL?

    /// - Parameter binary: The ffmpeg executable; `nil` makes the engine unavailable.
    public init(binary: URL?) {
        self.binary = binary
    }

    /// `Contents/Helpers/ffmpeg` inside `bundle`, when present and executable.
    public static func bundledBinary(in bundle: Bundle = .main) -> URL? {
        helper("ffmpeg", in: bundle)
    }

    /// `Contents/Helpers/ffprobe` inside `bundle`, when present and executable.
    public static func bundledProbe(in bundle: Bundle = .main) -> URL? {
        helper("ffprobe", in: bundle)
    }

    private static func helper(_ name: String, in bundle: Bundle) -> URL? {
        let url = bundle.bundleURL.appendingPathComponent("Contents/Helpers/\(name)")
        return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
    }

    public func canConvert(from source: FormatDescriptor, to target: FormatDescriptor) -> Bool {
        binary != nil
            && FFmpegArguments.readableFormats.contains(source.id.rawValue)
            && FFmpegArguments.output(for: target.id) != nil
    }

    public func convert(
        _ request: ConversionRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL] {
        guard let binary, let output = FFmpegArguments.output(for: request.targetFormat.id) else { throw .unsupported }
        guard FileManager.default.fileExists(atPath: request.source.path) else { throw .sourceMissing }
        let arguments = ["-i", request.source.path] + output + [request.destination.path]
        try await FFmpegRunner.run(binary: binary, arguments: arguments, progress: progress)
        progress(1)
        return [request.destination]
    }
}
#endif
