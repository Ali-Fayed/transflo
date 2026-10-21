import Foundation

/// Performs conversions with one technology (Strategy pattern).
public protocol ConversionEngine: Sendable {
    var id: EngineID { get }

    /// Whether this engine can perform the conversion on the running system.
    func canConvert(from source: FormatDescriptor, to target: FormatDescriptor) -> Bool

    /// Writes the output and returns every URL it created: usually just `request.destination`;
    /// multi-page results may instead be a folder beside it. Reports progress in `0...1`.
    /// Must not modify the source, and must remove anything it created if it fails.
    func convert(
        _ request: ConversionRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL]
}
