import Foundation
import TransfloDomain

/// Compress never keeps a result bigger than the original, the same rule GIF compression follows:
/// each preset is tried from the chosen level toward Smaller, and the first one that beats the
/// source is kept. If none does, the file is already as small as these settings make it.
enum ImageCompressionLadder {
    static func compress(
        _ source: URL,
        format: String,
        level: CompressionLevel,
        writer: ImageFileWriter,
        to output: URL,
        maximumLongEdge: Int? = nil,
        usesPresetSize: Bool = true,
        isCancelled: () -> Bool = { false }
    ) throws(JobError) {
        guard let original = bytes(of: source) else { throw .sourceMissing }
        let workspace = try TemporaryWorkspace(parent: output.deletingLastPathComponent())
        defer { workspace.remove() }
        for (attempt, candidateLevel) in CompressionLevel.allCases.drop(while: { $0 != level }).enumerated() {
            if isCancelled() { throw .cancelled }
            let candidate = workspace.url.appendingPathComponent("candidate-\(attempt).\(output.pathExtension)")
            try ImageCompressor.compress(source, format: format, level: candidateLevel, writer: writer,
                                         to: candidate, maximumLongEdge: maximumLongEdge,
                                         usesPresetSize: usesPresetSize)
            guard let size = bytes(of: candidate), size < original else { continue }
            do { try FileManager.default.moveItem(at: candidate, to: output) } catch { throw .failed }
            return
        }
        throw .nothingFound
    }

    static func bytes(of url: URL) -> Int? {
        try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
    }
}
