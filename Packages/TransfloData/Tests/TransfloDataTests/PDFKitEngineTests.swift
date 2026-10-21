import AppKit
import Foundation
import ImageIO
import PDFKit
import Testing
@testable import TransfloData
import TransfloDomain

@Suite("PDFKitEngine")
struct PDFKitEngineTests {
    private let pdf = SubtitleTests.format("pdf", family: .document)
    private let png = SubtitleTests.format("png", family: .image)
    private let txt = SubtitleTests.format("txt", family: .document)
    private let engine = PDFKitEngine(naming: NameOutputFileUseCase(checker: FileManagerExistenceChecker()))

    private func convert(_ source: URL, to target: FormatDescriptor, in folder: URL) async throws -> [URL] {
        let destination = folder.appendingPathComponent("report").appendingPathExtension(target.outputExtension)
        let request = ConversionRequest(
            source: source, destination: destination, sourceFormat: pdf, targetFormat: target
        )
        return try await engine.convert(request) { _ in }
    }

    @Test("a one-page PDF becomes one 300 DPI image")
    func singlePage() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = folder.url.appendingPathComponent("report.pdf")
        try DocumentFixtures.makePDF(pages: 1, to: source)
        try #require(PDFDocument(url: source)?.pageCount == 1)
        let outputs = try await convert(source, to: png, in: folder.url)
        let properties = try #require(CGImageSourceCreateWithURL(outputs[0] as CFURL, nil).flatMap {
            CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any]
        })
        #expect(outputs.map(\.lastPathComponent) == ["report.png"])
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 2550)
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == 3300)
    }

    @Test("multi-page PDFs export a numbered folder, avoiding name collisions")
    func multiPage() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = folder.url.appendingPathComponent("report.pdf")
        try DocumentFixtures.makePDF(pages: 3, to: source)
        let pageCount = try #require(PDFDocument(url: source)?.pageCount)
        try FileManager.default.createDirectory(
            at: folder.url.appendingPathComponent("report (PNG)"), withIntermediateDirectories: false
        )
        let outputs = try await convert(source, to: png, in: folder.url)
        #expect(outputs.map(\.lastPathComponent) == ["report (PNG) 2"])
        let pages = try FileManager.default.contentsOfDirectory(atPath: outputs[0].path).sorted()
        #expect(pages.count == pageCount)
        #expect(pages.first == "report 1.png")
    }

    @Test("rotated pages render in their displayed orientation")
    func rotation() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = folder.url.appendingPathComponent("report.pdf")
        try DocumentFixtures.makePDF(pages: 1, to: source)
        let document = try #require(PDFDocument(url: source))
        document.page(at: 0)?.rotation = 90
        try #require(document.write(to: source))
        let outputs = try await convert(source, to: png, in: folder.url)
        let properties = try #require(CGImageSourceCreateWithURL(outputs[0] as CFURL, nil).flatMap {
            CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any]
        })
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 3300)
    }

    @Test("password-protected and corrupt PDFs are refused")
    func refused() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = folder.url.appendingPathComponent("plain.pdf")
        try DocumentFixtures.makePDF(pages: 1, to: source)
        let locked = folder.url.appendingPathComponent("locked.pdf")
        let document = try #require(PDFDocument(url: source))
        let options: [PDFDocumentWriteOption: Any] = [.userPasswordOption: "secret", .ownerPasswordOption: "owner"]
        try #require(document.write(to: locked, withOptions: options))
        await #expect(throws: JobError.failed) { _ = try await convert(locked, to: txt, in: folder.url) }
        let corrupt = try folder.file("corrupt.pdf", contents: "%PDF-1.4 nope")
        await #expect(throws: JobError.failed) { _ = try await convert(corrupt, to: txt, in: folder.url) }
    }

    @Test("PDF text keeps every page")
    func text() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = folder.url.appendingPathComponent("report.pdf")
        try DocumentFixtures.makePDF(pages: 2, to: source)
        let outputs = try await convert(source, to: txt, in: folder.url)
        let text = try String(contentsOf: outputs[0], encoding: .utf8)
        // Two fixture pages × 140 greetings; wrapping may split phrases but never the word.
        #expect(text.components(separatedBy: "Hello").count - 1 == 280)
    }
}
