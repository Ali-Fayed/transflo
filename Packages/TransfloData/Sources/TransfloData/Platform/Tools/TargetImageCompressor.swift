import Foundation
import TransfloDomain

/// Stages the entire target search so cancellation and an unreachable budget cannot leave an output.
enum TargetImageCompressor {
    static func compress(
        _ source: URL,
        budget: (format: String, bytes: Int64),
        writer: ImageFileWriter,
        to output: URL,
        isCancelled: () -> Bool,
        maximumLongEdge: Int? = nil
    ) throws(JobError) {
        guard budget.bytes > 0 else { throw .targetUnreachable }
        guard let size = try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize else { throw .sourceMissing }
        if isCancelled() { throw .cancelled }
        let workspace = try TemporaryWorkspace(parent: output.deletingLastPathComponent())
        defer { workspace.remove() }
        let staged = workspace.url.appendingPathComponent(output.lastPathComponent)
        var decoded = try ImageDecoding.decodeUpright(source)
        var resized = false
        if let edge = maximumLongEdge, let smaller = ImageScaling.fit(decoded.image, longEdge: edge) {
            resized = smaller.width != decoded.image.width || smaller.height != decoded.image.height
            decoded = ImageDecoding.Decoded(
                image: smaller, properties: decoded.properties, pointSize: decoded.pointSize
            )
        }
        if Int64(size) <= budget.bytes && !resized {
            do { try FileManager.default.copyItem(at: source, to: staged) } catch { throw .destinationUnavailable }
        } else {
            let encoder = TargetImageEncoder(decoded: decoded, format: budget.format,
                                             writer: writer, workspace: workspace.url)
            let data = try TargetImageCompressionUseCase(encoder: encoder)
                .execute(targetBytes: budget.bytes, isCancelled: isCancelled)
            do { try data.write(to: staged, options: .atomic) } catch { throw .destinationUnavailable }
        }
        try ToolOutputPublisher.publish(staged, to: output, isCancelled: isCancelled)
    }
}
