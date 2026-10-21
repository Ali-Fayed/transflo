import Foundation
import ImageIO
import PDFKit
import Testing
@testable import TransfloData
import TransfloDomain

/// Checks actual decodability rather than accepting a matching extension or a zero-byte result.
enum VerificationSupport {
    enum Failure: Error { case unreadable(String), fixtureUnavailable(String), changedOriginal, timeout }

    static func timed(_ operation: @escaping @Sendable () async throws -> [URL]) async throws -> [URL] {
        let task = Task { try await operation() }
        let deadline = Task {
            do { try await Task.sleep(for: .seconds(45)) } catch { return }
            task.cancel()
        }
        defer { deadline.cancel() }
        return try await task.value
    }

    static func unchanged(_ source: URL, copy: URL) throws {
        let values = try source.resourceValues(forKeys: [.isDirectoryKey])
        if values.isDirectory == true {
            let original = try FileManager.default.subpathsOfDirectory(atPath: source.path).sorted()
            let copied = try FileManager.default.subpathsOfDirectory(atPath: copy.path).sorted()
            guard original == copied else { throw Failure.changedOriginal }
        } else {
            guard try Data(contentsOf: source) == Data(contentsOf: copy) else { throw Failure.changedOriginal }
        }
    }

    static func files(in outputs: [URL]) throws -> [URL] {
        try outputs.flatMap { output in
            let values = try output.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                return try FileManager.default.contentsOfDirectory(at: output, includingPropertiesForKeys: nil)
                    .filter { !$0.lastPathComponent.hasPrefix(".") }
            }
            return [output]
        }
    }

    static func validate(_ outputs: [URL], target: String? = nil) async throws {
        guard !outputs.isEmpty else { throw Failure.unreadable("no output") }
        if target == "pages" {
            for output in outputs {
                guard await DocumentFixtures.entries(of: output)?.contains(where: { $0.hasPrefix("Index/") }) == true
                else { throw Failure.unreadable("Pages package") }
            }
            return
        }
        let decoded = try files(in: outputs)
        guard !decoded.isEmpty else { throw Failure.unreadable("empty output directory") }
        for output in decoded {
            let size = try output.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size > 0 else { throw Failure.unreadable("empty output") }
            let format = target ?? output.pathExtension.lowercased()
            try await validateFile(output, format: format)
        }
    }

    private static func validateFile(_ output: URL, format: String) async throws {
        switch format {
        case "jpg", "png", "heic", "tiff", "bmp", "webp", "avif", "gif":
            guard let source = CGImageSourceCreateWithURL(output as CFURL, nil),
                  CGImageSourceCreateImageAtIndex(source, 0, nil) != nil else {
                throw Failure.unreadable("image decoding")
            }
        case "pdf":
            try validatePDF(output)
        case "xlsx", "ods", "csv", "tsv":
            guard !((try SpreadsheetFiles.read(output, format: format)).sheets.isEmpty) else {
                throw Failure.unreadable("spreadsheet")
            }
        case "docx", "epub":
            guard !(try DocumentReader.read(output, format: format).text.string.isEmpty) else {
                throw Failure.unreadable("document text")
            }
        case "pptx":
            let parts = ["ppt/presentation.xml", "ppt/slides/slide1.xml"]
            guard try OOXMLTestSupport.partsParse(output, required: parts) else {
                throw Failure.unreadable("slide XML")
            }
        default:
            try await validateOther(output, format: format)
        }
    }

    private static func validatePDF(_ output: URL) throws {
        guard let document = PDFDocument(url: output), document.pageCount > 0,
              document.page(at: 0)?.thumbnail(of: CGSize(width: 64, height: 64), for: .mediaBox)
                .tiffRepresentation != nil else { throw Failure.unreadable("PDF rendering") }
    }

    private static func validateOther(_ output: URL, format: String) async throws {
        if ["zip", "tar", "gz"].contains(format) {
            guard await DocumentFixtures.entries(of: output)?.isEmpty == false else {
                throw Failure.unreadable("archive listing")
            }
        } else if MediaFixtures.containerTokens[format] != nil {
            let info = try await FFprobe.info(binary: try #require(MediaFixtures.ffprobe), file: output)
            guard info.hasVideo || info.hasAudio else { throw Failure.unreadable("media streams") }
        } else {
            guard let text = String(data: try Data(contentsOf: output), encoding: .utf8), !text.isEmpty else {
                throw Failure.unreadable("text")
            }
        }
    }
}
