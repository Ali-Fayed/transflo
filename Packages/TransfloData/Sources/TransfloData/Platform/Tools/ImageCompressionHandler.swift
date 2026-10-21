import Foundation
import TransfloDomain

/// Resolves per-file budgets and explicit sizing, with private staging around every encoder.
enum ImageCompressionHandler {
    static func write(
        _ item: ToolItem,
        settings: ToolSettings,
        writer: ImageFileWriter,
        to output: URL,
        isCancelled: () -> Bool
    ) throws(JobError) {
        let source = item.url
        let format = item.format?.id.rawValue ?? ""
        let goal: CompressionGoal
        let edge: Int?
        let presetSize: Bool
        switch settings {
        case .compress(let value):
            goal = value
            edge = nil
            presetSize = true
        case let .compressImage(value, maximum):
            goal = value
            edge = maximum
            presetSize = false
        default: throw .unsupported
        }
        if let edge, !(1...16_384).contains(edge) { throw .unsupported }
        try OutputFile.write(to: output) { staged throws(JobError) in
            if case .level(let level) = goal {
                try ImageCompressionLadder.compress(source, format: format, level: level, writer: writer,
                                                    to: staged, maximumLongEdge: edge, usesPresetSize: presetSize,
                                                    isCancelled: isCancelled)
            } else {
                guard let size = try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
                    throw .sourceMissing
                }
                guard let bytes = goal.byteBudget(originalBytes: Int64(size)) else { throw .targetUnreachable }
                try TargetImageCompressor.compress(source, budget: (format, bytes), writer: writer, to: staged,
                                                    isCancelled: isCancelled, maximumLongEdge: edge)
            }
        }
    }
}
