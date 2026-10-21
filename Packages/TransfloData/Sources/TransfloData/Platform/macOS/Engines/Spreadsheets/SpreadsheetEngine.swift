#if os(macOS)
import Foundation
import TransfloDomain

/// XLSX, ODS, CSV and TSV to each other and to PDF.
public struct SpreadsheetEngine: ConversionEngine {
    public let id = EngineIDs.spreadsheet

    public init() {}

    public func canConvert(from source: FormatDescriptor, to target: FormatDescriptor) -> Bool {
        SpreadsheetFiles.readable.contains(source.id.rawValue) && SpreadsheetFiles.writable.contains(target.id.rawValue)
    }

    public func convert(
        _ request: ConversionRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL] {
        try await BlockingWork.runCancellable { isCancelled throws(JobError) in
            let workbook = try SpreadsheetFiles.read(request.source, format: request.sourceFormat.id.rawValue)
            progress(0.5)
            if isCancelled() { throw .cancelled }
            try SpreadsheetFiles.write(workbook, format: request.targetFormat.id.rawValue, to: request.destination)
        }
        progress(1)
        return [request.destination]
    }
}
#endif
