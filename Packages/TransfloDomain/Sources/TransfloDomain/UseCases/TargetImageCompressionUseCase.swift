import Foundation

/// A bounded search Strategy. Only successful candidate bytes leave the search; it never publishes a file.
public struct TargetImageCompressionUseCase {
    private let encoder: any ImageEncoding

    public init(encoder: any ImageEncoding) { self.encoder = encoder }

    public func execute(targetBytes: Int64, isCancelled: () -> Bool) throws(JobError) -> Data {
        guard targetBytes > 0 else { throw .targetUnreachable }
        for step in 0...6 {
            let scale = pow(0.85, Double(step))
            if let candidate = try search(targetBytes: targetBytes, scale: scale, isCancelled: isCancelled) {
                return candidate
            }
        }
        throw .targetUnreachable
    }

    private func search(
        targetBytes: Int64, scale: Double, isCancelled: () -> Bool
    ) throws(JobError) -> Data? {
        var low = 0.05
        var high = 0.95
        var best: Data?
        for pass in 0..<8 {
            if isCancelled() { throw .cancelled }
            let quality = pass == 0 ? low : (pass == 1 ? high : (low + high) / 2)
            let candidate = try encoder.encode(quality: quality, scale: scale)
            if isCancelled() { throw .cancelled }
            guard !candidate.isEmpty else { throw .failed }
            if Int64(candidate.count) <= targetBytes {
                if candidate.count > (best?.count ?? 0) { best = candidate }
                low = quality
                if pass == 1 || !encoder.supportsQualitySearch { break }
            } else {
                high = quality
                if pass == 0 || !encoder.supportsQualitySearch { break }
            }
        }
        return best
    }
}
