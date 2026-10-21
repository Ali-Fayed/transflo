#if os(macOS)
import Foundation
import TransfloDomain

/// Text documents: TXT, RTF, RTFD, text clippings, DOCX, Markdown and EPUB in;
/// TXT, DOCX, HTML, Markdown, EPUB and PDF out.
public struct DocumentsEngine: ConversionEngine {
    public let id = EngineIDs.documents
    static let readable: Set<String> = ["txt", "rtf", "rtfd", "clipping", "docx", "md", "epub"]
    static let writable: Set<String> = ["txt", "docx", "html", "md", "epub", "pdf"]

    public init() {}

    public func canConvert(from source: FormatDescriptor, to target: FormatDescriptor) -> Bool {
        Self.readable.contains(source.id.rawValue) && Self.writable.contains(target.id.rawValue)
    }

    public func convert(
        _ request: ConversionRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL] {
        try await BlockingWork.runCancellable { isCancelled throws(JobError) in
            let document = try DocumentReader.read(request.source, format: request.sourceFormat.id.rawValue)
            progress(0.5)
            if isCancelled() { throw .cancelled }
            let title = request.source.deletingPathExtension().lastPathComponent
            let target = request.targetFormat.id.rawValue
            try DocumentWriter.write(document, format: target, title: title, to: request.destination)
        }
        progress(1)
        return [request.destination]
    }
}
#endif
