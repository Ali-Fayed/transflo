import Foundation
import TransfloDomain

/// SRT ↔ WebVTT, and either to plain text (dialogue only).
public struct SubtitleEngine: ConversionEngine {
    public let id = EngineIDs.subtitle

    public init() {}

    public func canConvert(from source: FormatDescriptor, to target: FormatDescriptor) -> Bool {
        ["srt", "vtt"].contains(source.id.rawValue) && style(for: target.id.rawValue) != nil
    }

    public func convert(
        _ request: ConversionRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL] {
        guard let style = style(for: request.targetFormat.id.rawValue) else { throw .unsupported }
        let cues = SubtitleParser.cues(from: try TextFileReader.read(request.source))
        guard !cues.isEmpty else { throw .failed }
        try TextFileReader.write(SubtitleWriter.text(for: cues, style: style), to: request.destination)
        progress(1)
        return [request.destination]
    }

    private func style(for target: String) -> SubtitleWriter.Style? {
        switch target {
        case "srt": .srt
        case "vtt": .vtt
        case "txt": .plainText
        default: nil
        }
    }
}
